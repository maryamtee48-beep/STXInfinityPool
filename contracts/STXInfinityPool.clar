
;; STXInfinityPool
;; <add a description here>


;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-not-active-staker (err u102))
(define-constant err-no-rewards (err u103))
(define-constant err-invalid-tier (err u104))
(define-constant err-proposal-not-active (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-cooldown-active (err u107))

;; Staking tiers (in STX)
(define-constant tier-1-minimum u100000000) ;; 100 STX
(define-constant tier-2-minimum u1000000000) ;; 1,000 STX
(define-constant tier-3-minimum u10000000000) ;; 10,000 STX

;; Reward multipliers (base points)
(define-constant tier-1-multiplier u1000) ;; 1x
(define-constant tier-2-multiplier u1250) ;; 1.25x
(define-constant tier-3-multiplier u1500) ;; 1.5x

;; Timelock and cooldown periods
(define-constant unstake-cooldown-blocks u100) ;; Blocks required between unstaking
(define-constant governance-voting-period u1440) ;; ~10 days in blocks

;; Data Variables
(define-data-var total-staked uint u0)
(define-data-var pool-active bool true)
(define-data-var reward-cycle uint u0)
(define-data-var total-rewards uint u0)
(define-data-var governance-proposal-id uint u0)
(define-data-var last-price uint u0)

;; Data Maps
(define-map staker-balances principal uint)
(define-map staker-rewards principal uint)
(define-map staker-tiers principal uint)
(define-map reward-distribution uint uint)
(define-map referral-rewards {referrer: principal, referee: principal} uint)
(define-map last-unstake-block principal uint)
(define-map governance-proposals uint {
    proposer: principal,
    start-block: uint,
    end-block: uint,
    description: (string-utf8 256),
    active: bool
})

;; Read-only functions
(define-read-only (get-staker-balance (staker principal))
    (default-to u0 (map-get? staker-balances staker))
)


(define-map governance-votes {proposal: uint, voter: principal} bool)
(define-map governance-vote-counts uint {yes: uint, no: uint})

;; Referral System
(define-public (register-referral (referrer principal))
    (let (
        (referee tx-sender)
        (referral-bonus (/ (var-get total-staked) u100)) ;; 1% bonus
    )
    (map-set referral-rewards {referrer: referrer, referee: referee} referral-bonus)
    (ok referral-bonus))
)

(define-read-only (get-referral-bonus (referrer principal) (referee principal))
    (default-to u0 (map-get? referral-rewards {referrer: referrer, referee: referee}))
)

;; Enhanced Staking with Tiers
(define-public (stake (amount uint))
    (let (
        (current-balance (get-staker-balance tx-sender))
        (new-balance (+ current-balance amount))
        (tier (determine-tier new-balance))
    )
    (asserts! (>= amount tier-1-minimum) (err u108))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update staker's balance and tier
    (map-set staker-balances tx-sender new-balance)
    (map-set staker-tiers tx-sender tier)

    ;; Update total staked amount
    (var-set total-staked (+ (var-get total-staked) amount))

    (ok amount))
)

;; Tiered unstaking with cooldown
(define-public (unstake (amount uint))
    (let (
        (current-balance (get-staker-balance tx-sender))
        (last-unstake (default-to u0 (map-get? last-unstake-block tx-sender)))
        (current-block block-height)
    )
    (asserts! (>= current-balance amount) err-insufficient-funds)
    (asserts! (>= (- current-block last-unstake) unstake-cooldown-blocks) err-cooldown-active)

    ;; Transfer STX back to staker
    (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))

    ;; Update staker's balance and record unstake block
    (map-set staker-balances tx-sender (- current-balance amount))
    (map-set last-unstake-block tx-sender current-block)

    ;; Update total staked amount
    (var-set total-staked (- (var-get total-staked) amount))

    (ok amount))
)


;; Helper functions
(define-private (determine-tier (balance uint))
    (if (>= balance tier-3-minimum)
        u3
        (if (>= balance tier-2-minimum)
            u2
            u1))
)

;; Governance System
(define-public (create-proposal (description (string-utf8 256)))
    (let (
        (proposal-id (var-get governance-proposal-id))
        (start-block block-height)
        (end-block (+ start-block governance-voting-period))
        (staker-balance (get-staker-balance tx-sender))
    )
    (asserts! (>= staker-balance tier-2-minimum) (err u109))

    ;; Create new proposal
    (map-set governance-proposals proposal-id {
        proposer: tx-sender,
        start-block: start-block,
        end-block: end-block,
        description: description,
        active: true
    })

    ;; Initialize vote counts
    (map-set governance-vote-counts proposal-id {yes: u0, no: u0})

    ;; Increment proposal ID
    (var-set governance-proposal-id (+ proposal-id u1))

    (ok proposal-id))
)

(define-public (vote (proposal-id uint) (vote-bool bool))
    (let (
        (proposal (unwrap! (map-get? governance-proposals proposal-id) err-proposal-not-active))
        (vote-power (get-vote-power tx-sender))
        (current-votes (default-to {yes: u0, no: u0} (map-get? governance-vote-counts proposal-id)))
    )
    (asserts! (not (default-to false (map-get? governance-votes {proposal: proposal-id, voter: tx-sender}))) err-already-voted)
    (asserts! (and (>= block-height (get start-block proposal)) (<= block-height (get end-block proposal))) err-proposal-not-active)

    ;; Record vote
    (map-set governance-votes {proposal: proposal-id, voter: tx-sender} vote-bool)

    ;; Update vote counts
    (if vote-bool
        (map-set governance-vote-counts proposal-id 
            {yes: (+ (get yes current-votes) vote-power), 
             no: (get no current-votes)})
        (map-set governance-vote-counts proposal-id 
            {yes: (get yes current-votes), 
             no: (+ (get no current-votes) vote-power)}))

    (ok true))
)



(define-private (get-vote-power (staker principal))
    (let (
        (balance (get-staker-balance staker))
        (tier (default-to u1 (map-get? staker-tiers staker)))
    )
    (/ (* balance tier) u100)) ;; Vote power = balance * tier / 100
)

;; Price Oracle Integration
(define-public (update-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set last-price new-price)
        (ok new-price))
)

;; Enhanced reward calculation with tiers
(define-public (calculate-rewards (staker principal))
    (let (
        (staker-balance (get-staker-balance staker))
        (staker-tier (default-to u1 (map-get? staker-tiers staker)))
        (tier-multiplier (get-tier-multiplier staker-tier))
        (total (var-get total-staked))
        (cycle-rewards (default-to u0 (map-get? reward-distribution (- (var-get reward-cycle) u1))))
    )
    (if (is-eq total u0)
        (ok u0)
        (ok (/ (* (* staker-balance cycle-rewards) tier-multiplier) (* total u1000))))
))

(define-private (get-tier-multiplier (tier uint))
    (if (is-eq tier u3)
        tier-3-multiplier
        (if (is-eq tier u2)
            tier-2-multiplier
            tier-1-multiplier))
)

;; Emergency functions with timelock
(define-data-var emergency-timelock uint u0)
(define-constant timelock-delay u144) ;; ~24 hours in blocks

(define-public (initiate-emergency-withdrawal)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-timelock (+ block-height timelock-delay))
        (ok block-height))
)

(define-public (execute-emergency-withdrawal)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (>= block-height (var-get emergency-timelock)) (err u110))
        (let (
            (balance (stx-get-balance (as-contract tx-sender)))
        )
        (try! (as-contract (stx-transfer? balance (as-contract tx-sender) contract-owner)))
        (ok balance)))
)

