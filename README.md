

# STXInfinityPool Contract

A feature-rich, secure, and extensible **Clarity smart contract** for staking STX with **tiered rewards**, **governance**, **referrals**, and **emergency protocols**.

---

## 🚀 Features

### ✅ Staking & Unstaking

* Stake STX tokens and earn rewards.
* Three reward **tiers** based on staking volume.
* Unstaking includes a **cooldown period** to prevent abuse.

### 🎖️ Tier System

| Tier | Minimum STX | Reward Multiplier |
| ---- | ----------- | ----------------- |
| 1    | 100 STX     | 1.0x              |
| 2    | 1,000 STX   | 1.25x             |
| 3    | 10,000 STX  | 1.5x              |

Tier is auto-assigned on staking and updated dynamically.

### 🎁 Rewards System

* Rewards are calculated proportionally to stake and tier.
* Rewards are distributed per cycle.
* Uses a **multiplier system** for fairness across tiers.

### 🧑‍🤝‍🧑 Referral Program

* Referees can register a referrer.
* Referrers get 1% bonus of total staked amount (one-time).

### 🗳 Governance

* Only Tier 2+ stakers can create proposals.
* All stakers can vote based on their **vote power**:

  ```
  votePower = (stakedBalance * tier) / 100
  ```
* Proposals last \~10 days (1440 blocks).
* One vote per proposal per user.

### 💹 Price Oracle Integration

* Owner can update a price feed via `update-price`.

### 🔐 Emergency Withdrawals

* Owner can initiate an **emergency withdrawal** with a 24-hour timelock (144 blocks).
* After delay, funds can be withdrawn to the contract owner.

---

## 🛡️ Security Features

* Access control for owner-only functions.
* Timelocks for emergency withdrawals.
* Cooldown periods between unstakes.
* Proposal voting locked to active windows only.

---

## 📚 Public Functions Overview

| Function                        | Description                     |
| ------------------------------- | ------------------------------- |
| `stake`                         | Stake STX and set tier          |
| `unstake`                       | Withdraw STX after cooldown     |
| `register-referral`             | Registers referral relationship |
| `create-proposal`               | Governance proposal creation    |
| `vote`                          | Vote on a proposal              |
| `calculate-rewards`             | View potential rewards          |
| `update-price`                  | Owner updates price oracle      |
| `initiate-emergency-withdrawal` | Starts the timelock             |
| `execute-emergency-withdrawal`  | Executes withdrawal after delay |

---

## 🧠 Data Storage

* `staker-balances`: Map of user → staked STX
* `staker-tiers`: Map of user → tier
* `reward-distribution`: Map of cycle → total rewards
* `referral-rewards`: Map of {referrer, referee} → bonus
* `governance-proposals`: Proposal metadata
* `governance-votes`: User votes
* `governance-vote-counts`: Aggregated votes
* `last-unstake-block`: Prevents rapid unstaking

---

## 🧪 Deployment Checklist

* [ ] Test staking and unstaking with all tiers.
* [ ] Validate cooldown logic on `unstake`.
* [ ] Test governance flow: proposal → voting → counting.
* [ ] Test referral bonuses.
* [ ] Simulate emergency withdrawal and timelock.
* [ ] Ensure `update-price` is only callable by owner.

---

## 🧾 Constants Reference

* `tier-1-minimum`: `u100_000_000` (100 STX)
* `tier-2-minimum`: `u1_000_000_000` (1,000 STX)
* `tier-3-minimum`: `u10_000_000_000` (10,000 STX)
* `unstake-cooldown-blocks`: `u100`
* `governance-voting-period`: `u1440`
* `timelock-delay`: `u144` (\~24 hours)

---

## ⚠ Errors

| Code  | Description                     |
| ----- | ------------------------------- |
| `100` | Only owner can call             |
| `101` | Insufficient funds              |
| `102` | Not an active staker            |
| `103` | No rewards                      |
| `104` | Invalid tier                    |
| `105` | Proposal not active             |
| `106` | Already voted                   |
| `107` | Cooldown active                 |
| `108` | Stake too small                 |
| `109` | Not eligible to create proposal |
| `110` | Emergency timelock active       |

---
