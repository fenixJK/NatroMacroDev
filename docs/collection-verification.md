# Collection failure recovery

The failed-visit path now preserves the existing cooldown for Wealth Clock,
Honey/Treat/Blueberry/Strawberry/Coconut/Glue/Royal Jelly dispensers, Stockings,
Feast, Gingerbread House, Snow Machine, Candles, Samovar, Lid Art, Gummy Beacon,
RBP De-level and Memory Match. Two misses reserve a five-minute retry delay instead
of assigning the full collection cooldown. Seasonal and Memory Match gather
interrupts honor that delay, including Night Memory Match.

`CollectionRecovery` INI entries contain `lastAttempt|retryAfter|lastInteraction`.
Reservation happens after eligibility checks and before travel. Failure renews the
delay from the end of the visit. Existing `Collect/Last...` values are preserved on
failure and continue to drive normal cooldowns. Recovery metadata survives restart;
it is not an atomic journal for all collection state.

## What the automated tests establish

- The five extracted dispenser routines run both failed attempts against controlled
  missing-prompt observations. They preserve memory/disk cooldowns, suppress an
  immediate revisit, and retry at the five-minute boundary without sending input.
- An interrupted actual dispenser observation retains the pre-travel reservation.
- Production recovery methods cover two failed visits followed by a recorded
  interaction, long travel, abandoned reservations, malformed metadata and a
  backward wall-clock change.
- Production seasonal and Memory Match interrupt functions allow gathering during
  backoff and become eligible at its end. Disabled/excluded dispenser routes do not
  reserve attempts.

## Remaining acceptance and live gates

The legacy interaction path still finds an E prompt and sends input; that is not
positive evidence of a granted reward. The metadata deliberately calls this an
interaction, not a verified success. Existing "Collected" status messages and full
cooldowns after that path retain this limitation. F13 is therefore only partially
resolved. Do not count these tests as successful live collection or Memory Match.

Still required:

1. Record fresh before/after images for every device: available, cooldown, inventory
   full, rejected input, delayed reward and changed focus/window geometry.
2. Identify a positive accepted-interaction or observed-cooldown signal; require it
   before committing a verified success and displaying "Collected".
3. Verify reward/loot routes, gumdrop use for Glue, and Memory Match entry separately
   from travel/prompt detection. Test interruption during input and loot collection.
4. Exercise Night Memory Match failure during night with Vicious Bee both enabled
   and disabled, ensuring the independent Vicious Bee interrupt remains functional.
5. Cover all remaining seasonal routines with recorded observations and live routes;
   current actual-routine failure tests cover the five simple dispensers only.
6. Reconcile the separate field-booster/Coconut boost-chaser failure path, which still
   adjusts legacy cooldown timestamps. Ant/Robo passes, Wreath, Honeystorm and other
   collection families also need the common acceptance/recovery policy.

No Windows/Roblox machine is currently available. None of these live gates is
marked passed; the production recovery plan remains active.
