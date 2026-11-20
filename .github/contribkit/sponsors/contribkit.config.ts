import { defineConfig, tierPresets } from '@lizardbyte/contribkit'

export default defineConfig({
  tiers: [
    { title: 'Backers', preset: tierPresets.small },
    { title: 'Sponsors', monthlyDollars: 10, preset: tierPresets.base },
    { title: 'Silver Sponsors', monthlyDollars: 50, preset: tierPresets.medium },
    { title: 'Gold Sponsors', monthlyDollars: 100, preset: tierPresets.large },
    { title: 'Platinum Sponsors', monthlyDollars: 500, preset: tierPresets.xl },
  ],
})
