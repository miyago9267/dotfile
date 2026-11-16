import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { AgentRow } from '../types'

// Nord palette, matching coralline's nord theme.
const C = {
  text: '#2e3440',
  light: '#eceff4',
  run: '#88c0d0',
  wait: '#ebcb8b',
  idle: '#4c566a',
  fail: '#bf616a',
  time: '#81a1c1',
}
const CAP_L = ''
const CAP_R = ''
const SEP = ''
const SPIN = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
const LIVE = new Set(['pending', 'running', 'waiting', 'idle'])
const MAX_ROWS = 5

const rows = atom({ plugin: 'coralline-agents', key: 'rows' } as const, [], { shape: 'rows-1' })
const tick = atom({ plugin: 'coralline-agents', key: 'tick' } as const, 0)

const elapsed = (ms: number) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  const m = Math.floor(s / 60)
  const h = Math.floor(m / 60)
  return h ? `${h}h${String(m % 60).padStart(2, '0')}m` : m ? `${m}m${String(s % 60).padStart(2, '0')}s` : `${s}s`
}

const statusColor = (status: string) =>
  status === 'running' || status === 'pending' ? C.run : status === 'waiting' ? C.wait : status === 'failed' ? C.fail : C.idle

export const register: Register = on => {
  const firstSeen = new Map<string, number>()

  on('session.start', async ($, e, next) => {
    $.clock.every(1000, async () => {
      const now = await $.clock.now()
      const live = (await $.agent.list()).filter(a => LIVE.has(a.status))
      const ids = new Set(live.map(a => a.id))
      for (const id of firstSeen.keys()) if (!ids.has(id)) firstSeen.delete(id)
      const current: AgentRow[] = live.map(a => {
        if (!firstSeen.has(a.id)) firstSeen.set(a.id, now)
        return { id: a.id, type: a.type, description: a.description, status: a.status, startedAt: firstSeen.get(a.id)! }
      })
      const prev = await read($, rows)
      if (current.length === 0 && prev.length === 0) return
      await update($, rows, () => current)
      await update($, tick, t => t + 1)
    })

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const list = await read($, rows)
    if (e.props.hasSurvey || list.length === 0) return next(e)

    const t = await read($, tick)
    const now = await $.clock.now()
    const { Box, Text } = $.ui.resolve(e)
    const shown = list.slice(0, MAX_ROWS)

    return (
      <Box flexDirection="column">
        {shown.map(a => {
          const bg = statusColor(a.status)
          const fg = bg === C.idle || bg === C.fail ? C.light : C.text
          const mark = a.status === 'running' || a.status === 'pending' ? SPIN[t % SPIN.length] : a.status === 'waiting' ? '⧗' : '○'
          return (
            <Box key={a.id} flexDirection="row">
              <Text color={bg}>{CAP_L}</Text>
              <Text color={fg} backgroundColor={bg} bold wrap="truncate-end">
                {` ${mark} ${a.type} · ${a.description} `}
              </Text>
              <Text color={bg} backgroundColor={C.time}>{SEP}</Text>
              <Text color={C.text} backgroundColor={C.time}>{` ⧖ ${elapsed(now - a.startedAt)} `}</Text>
              <Text color={C.time}>{CAP_R}</Text>
            </Box>
          )
        })}
        {list.length > MAX_ROWS ? <Text dimColor>{`  +${list.length - MAX_ROWS} more`}</Text> : null}
      </Box>
    )
  })
}
