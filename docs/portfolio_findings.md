# Portfolio Findings

The dashboard is based on a synthetic credit portfolio. Current portfolio metrics include active, defaulted and restructured contracts; closed contracts are excluded.

## Portfolio snapshot

| Metric | Value |
|---|---:|
| Total outstanding | ₽2.00 bn |
| Total overdue | ₽43.99 mln |
| Delinquency rate | 41.82% |
| DPD 30+ rate | 31.27% |
| DPD 90+ rate | 19.00% |
| PAR 30 | 21.02% |
| PAR 90 | 4.75% |
| Overdue share | 2.20% |

Almost one third of current contracts are at DPD 30+, and 19% have reached DPD 90+. The balance-based figures are lower: PAR 30 is 21.02%, while PAR 90 is 4.75%.

The difference between DPD 90+ rate and PAR 90 shows that severe delinquency affects a larger share of contracts than of the outstanding balance.

## Score bands

| Score band | DPD 30+ rate | DPD 90+ rate |
|---|---:|---:|
| 350–449 | 47.52% | 28.22% |
| 450–549 | 45.45% | 28.34% |
| 550–649 | 21.28% | 11.70% |
| 650–749 | 6.03% | 4.02% |
| 750–850 | 1.79% | 1.79% |

The clearest risk split is around a score of 550. DPD 30+ affects about 45–48% of contracts in the two lowest bands, compared with 6% or less above 650.

The synthetic scoring model therefore separates the generated risk profiles reasonably well.

## Original loan size

| Original loan size | DPD 30+ rate | PAR 30 |
|---|---:|---:|
| Up to ₽1 million | 44.22% | 25.26% |
| ₽1–3 million | 30.92% | 20.16% |
| Above ₽3 million | 23.23% | 21.01% |

Smaller loans fall into DPD 30+ more often. However, the difference in PAR 30 is much smaller because larger contracts carry more outstanding principal.

Looking only at the number of delinquent contracts would therefore overstate the difference between the loan-size segments.

## Delinquency resolution

| Maximum DPD | Total events | Open events | Resolution rate | Avg. days to resolution |
|---|---:|---:|---:|---:|
| 1–7 | 2,428 | 44 | 98.19% | 1.03 |
| 8–30 | 266 | 152 | 42.86% | 9.00 |
| 31–60 | 120 | 120 | 0.00% | — |
| 61–90 | 66 | 66 | 0.00% | — |
| 91+ | 368 | 368 | 0.00% | — |

Most short delinquency events are resolved quickly. The resolution rate falls from 98.19% in the 1–7 DPD bucket to 42.86% in the 8–30 bucket.

All generated events that reached 31+ DPD remain open in the current snapshot. This is largely a result of the synthetic payment-behaviour rules, so these figures should not be treated as real portfolio cure rates.

## Payment performance

For most historical months, the collection rate is higher than the on-time payment rate. In other words, some payments arrive late but are eventually collected.

Both measures fall near the end of the observed period. The latest values combine actual unpaid synthetic instalments with a shorter observation window for recent due dates, so the final months are not directly comparable with older periods.

## Main takeaways

- Score bands below 550 contain the highest concentration of delinquent contracts.
- The early delinquency stage is the main point at which most events are still resolved.
- Contract-level delinquency rates should be read together with PAR metrics.
- The high-risk watchlist should be prioritised by current DPD and outstanding balance.

## Limitation

The portfolio is synthetic and follows predefined behavioural rules. The results demonstrate the analytical workflow and should not be interpreted as evidence about a real lending portfolio.
