export type AgentRow = { id: string; type: string; description: string; status: string; startedAt: number }

declare module 'claude-code' {
  interface PluginState {
    'coralline-agents': { rows: Shaped<AgentRow[]>; tick: number }
  }
}
