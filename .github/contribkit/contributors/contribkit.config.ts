import { defineConfig, tierPresets } from '@lizardbyte/contribkit'

export default defineConfig({
  tiers: [
    { title: 'Newcomers', preset: tierPresets.base },
    { title: 'Regulars', monthlyDollars: 12, preset: tierPresets.medium },
    { title: 'Veterans', monthlyDollars: 25, preset: tierPresets.large },
    { title: 'Legends', monthlyDollars: 50, preset: tierPresets.xl },
  ],
})
