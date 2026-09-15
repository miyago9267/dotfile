// Restore usable GitHub Copilot models when the remote picker flag is stale.
export const CopilotModelSync = async () => ({
  provider: {
    id: "github-copilot",
    async models(provider, ctx) {
      if (ctx.auth?.type !== "oauth") return provider.models

      const enterprise = ctx.auth.enterpriseUrl
        ?.replace(/^https?:\/\//, "")
        .replace(/\/$/, "")
      const base = enterprise
        ? `https://copilot-api.${enterprise}`
        : "https://api.githubcopilot.com"
      const response = await fetch(`${base}/models`, {
        headers: {
          Authorization: `Bearer ${ctx.auth.refresh}`,
          "User-Agent": "opencode/1.18.19",
          "X-GitHub-Api-Version": "2026-06-01",
        },
        signal: AbortSignal.timeout(5000),
      })

      if (!response.ok) return provider.models

      const payload = await response.json()
      const models = {}

      for (const remote of payload.data ?? []) {
        if (/^(copilot-search-|exec-agent-|trajectory-compaction$)/.test(remote.id)) continue
        if (remote.policy?.state === "disabled") continue

        const limits = remote.capabilities?.limits
        const supports = remote.capabilities?.supports
        if (
          typeof limits?.max_output_tokens !== "number" ||
          typeof limits?.max_prompt_tokens !== "number" ||
          supports?.tool_calls !== true
        ) continue

        const messages = remote.supported_endpoints?.includes("/v1/messages")
        models[remote.id] = {
          id: remote.id,
          providerID: "github-copilot",
          api: {
            id: remote.id,
            url: messages ? `${base}/v1` : base,
            npm: messages ? "@ai-sdk/anthropic" : "@ai-sdk/github-copilot",
          },
          status: "active",
          name: remote.name,
          limit: {
            context: limits.max_context_window_tokens ?? limits.max_prompt_tokens,
            input: limits.max_prompt_tokens,
            output: limits.max_output_tokens,
          },
          capabilities: {
            temperature: true,
            reasoning: true,
            attachment: true,
            toolcall: true,
            input: {
              text: true,
              audio: false,
              image: supports.vision === true,
              video: false,
              pdf: false,
            },
            output: {
              text: true,
              audio: false,
              image: false,
              video: false,
              pdf: false,
            },
            interleaved: false,
          },
          family: remote.capabilities?.family,
          cost: {
            input: 0,
            output: 0,
            cache: { read: 0, write: 0 },
          },
          options: {},
          headers: {},
        }
      }

      return Object.keys(models).length > 0 ? models : provider.models
    },
  },
})
