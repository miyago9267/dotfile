#!/usr/bin/env bash
# ops-write-guard: PreToolUse hook
# Tier 1 (any cluster, ask):  destructive verbs
# Tier 2 (production ask):    mutating verbs
# Tier 3 (all):               show context+namespace (systemMessage, no block)
# Bypass: env SRE_GUARD_BYPASS=<reason> inline

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# --- bypass ---
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|])SRE_GUARD_BYPASS='; then
  reason=$(printf '%s' "$cmd" | grep -oE 'SRE_GUARD_BYPASS=[^[:space:];&|]+' | head -1 | cut -d= -f2)
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:("ops-write-guard bypass: "+$r)}}'
  exit 0
fi

# --- detect kubectl / gcloud ---
is_kubectl=0; is_gcloud=0
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|`(])kubectl([[:space:]]|$)'; then is_kubectl=1; fi
if printf '%s' "$cmd" | grep -qE '(^|[[:space:];&|`(])gcloud([[:space:]]|$)'; then is_gcloud=1; fi
[ $is_kubectl -eq 0 ] && [ $is_gcloud -eq 0 ] && exit 0

# --- extract verb ---
verb=""
if [ $is_kubectl -eq 1 ]; then
  # Strip everything up to and including the first "kubectl " token, then scan tokens
  tail_part=$(printf '%s' "$cmd" | awk '{
    for (i=1; i<=NF; i++) if ($i == "kubectl") { for (j=i+1; j<=NF; j++) printf "%s ", $j; print ""; exit }
  }')
  verb=$(printf '%s' "$tail_part" | awk '
    {
      skip=0
      for (i=1; i<=NF; i++) {
        t=$i
        if (skip) { skip=0; continue }
        # flags with separate value
        if (t == "-n" || t == "--namespace" || t == "--context" || t == "--kubeconfig" || t == "-c" || t == "--container" || t == "--cluster" || t == "--user") { skip=1; continue }
        # flag=value or other flags
        if (t ~ /^-/) { continue }
        print t; exit
      }
    }')
  if [ "$verb" = "rollout" ] || [ "$verb" = "config" ]; then
    sub=$(printf '%s' "$tail_part" | awk -v v="$verb" '
      {
        found=0; skip=0
        for (i=1; i<=NF; i++) {
          t=$i
          if (skip) { skip=0; continue }
          if (t == "-n" || t == "--namespace" || t == "--context" || t == "--kubeconfig") { skip=1; continue }
          if (t ~ /^-/) { continue }
          if (found) { print t; exit }
          if (t == v) { found=1 }
        }
      }')
    [ -n "$sub" ] && verb="$verb $sub"
  fi
fi
if [ $is_gcloud -eq 1 ] && [ -z "$verb" ]; then
  # gcloud <group> <verb> ...; we look for known destructive patterns
  verb=$(printf '%s' "$cmd" | sed -E 's/.*\bgcloud[[:space:]]+//')
fi

# --- classify ---
tier=0  # 0=safe, 1=Tier1, 2=Tier2, 3=Tier3
reason=""

if [ $is_kubectl -eq 1 ]; then
  case "$verb" in
    delete|drain|cordon|uncordon|replace|taint)
      tier=1; reason="kubectl $verb is destructive (Tier 1)"
      ;;
    apply|patch|edit|scale|annotate|label|set|create|"rollout restart"|"rollout undo"|"rollout pause"|"rollout resume")
      tier=2; reason="kubectl $verb is mutating (Tier 2)"
      ;;
    exec|cp|"port-forward"|attach|proxy|"config use-context")
      tier=3; reason="kubectl $verb (context-sensitive)"
      ;;
    *)
      tier=0
      ;;
  esac

  # Special case: switching INTO a production cluster -> escalate to Tier 1
  if [ "$verb" = "config use-context" ]; then
    target_ctx=$(printf '%s' "$cmd" | awk '
      {
        for (i=1; i<=NF; i++) {
          if ($i == "use-context" && (i+1) <= NF) { print $(i+1); exit }
        }
      }')
    if printf '%s' "$target_ctx" | grep -qi 'production'; then
      tier=1
      reason="kubectl config use-context -> PRODUCTION cluster ($target_ctx)"
    fi
  fi
fi

if [ $is_gcloud -eq 1 ] && [ $tier -eq 0 ]; then
  if printf '%s' "$cmd" | grep -qE 'gcloud[[:space:]]+(compute[[:space:]]+instances[[:space:]]+(delete|stop|reset)|sql[[:space:]]+instances[[:space:]]+delete|secrets[[:space:]]+delete|projects[[:space:]]+delete|container[[:space:]]+clusters[[:space:]]+delete)'; then
    tier=1; reason="gcloud destructive (Tier 1)"
  elif printf '%s' "$cmd" | grep -qE 'gcloud[[:space:]]+[a-z-]+([[:space:]]+[a-z-]+)?[[:space:]]+(update|set-iam-policy|add-iam-policy-binding|remove-iam-policy-binding|create|replace)'; then
    tier=2; reason="gcloud mutating (Tier 2)"
  fi
fi

[ $tier -eq 0 ] && exit 0

# --- discover current context ---
current_ctx=""; current_ns=""
if printf '%s' "$cmd" | grep -qE '\-\-context[=[:space:]]'; then
  current_ctx=$(printf '%s' "$cmd" | grep -oE '\-\-context[= ][^[:space:]]+' | head -1 | sed -E 's/--context[= ]//')
elif [ $is_kubectl -eq 1 ] && command -v kubectl >/dev/null 2>&1; then
  current_ctx=$(kubectl config current-context 2>/dev/null)
fi
if printf '%s' "$cmd" | grep -qE '(\-n|--namespace)[=[:space:]]'; then
  current_ns=$(printf '%s' "$cmd" | grep -oE '(\-n|--namespace)[= ][^[:space:]]+' | head -1 | sed -E 's/(--namespace|-n)[= ]//')
fi

is_prod=0
if printf '%s' "$current_ctx" | grep -qi 'production'; then is_prod=1; fi

# --- decide ---
ctx_label="${current_ctx:-<unknown>}"
ns_label="${current_ns:-<default>}"

case $tier in
  1)
    jq -n --arg r "$reason" --arg c "$ctx_label" --arg n "$ns_label" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: ("Tier 1 destructive op. context="+$c+" ns="+$n+" -- "+$r+". Bypass via inline SRE_GUARD_BYPASS=<reason>.")
      }
    }'
    ;;
  2)
    if [ $is_prod -eq 1 ]; then
      jq -n --arg r "$reason" --arg c "$ctx_label" --arg n "$ns_label" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: ("Tier 2 mutating on PRODUCTION. context="+$c+" ns="+$n+" -- "+$r+". Bypass via inline SRE_GUARD_BYPASS=<reason>.")
        }
      }'
    else
      jq -n --arg c "$ctx_label" --arg n "$ns_label" --arg r "$reason" '{
        systemMessage: ("[ops-write-guard] Tier 2 non-prod -- context="+$c+" ns="+$n+" ("+$r+")")
      }'
    fi
    ;;
  3)
    jq -n --arg c "$ctx_label" --arg n "$ns_label" --arg r "$reason" '{
      systemMessage: ("[ops-write-guard] context="+$c+" ns="+$n+" ("+$r+")")
    }'
    ;;
esac

exit 0
