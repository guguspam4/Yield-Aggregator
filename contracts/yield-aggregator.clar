(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u1002))
(define-constant ERR_STRATEGY_NOT_FOUND (err u1003))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u1004))
(define-constant ERR_INVALID_STRATEGY_ID (err u1005))
(define-constant ERR_REBALANCING_DISABLED (err u1006))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1007))
(define-constant ERR_DEPOSITS_PAUSED (err u1008))
(define-constant ERR_WITHDRAWALS_PAUSED (err u1009))
(define-constant ERR_REBALANCING_PAUSED (err u1010))
(define-constant ERR_SYSTEM_PAUSED (err u1011))
(define-constant ERR_INVALID_LOCK_PERIOD (err u1012))
(define-constant ERR_FUNDS_STILL_LOCKED (err u1013))
(define-constant ERR_NO_LOCKED_DEPOSIT (err u1014))
(define-constant ERR_LOCK_ALREADY_EXISTS (err u1015))

(define-data-var total-deposited uint u0)
(define-data-var total-shares uint u0)
(define-data-var next-strategy-id uint u1)
(define-data-var rebalancing-enabled bool true)
(define-data-var management-fee uint u100)
(define-data-var performance-fee uint u1000)
(define-data-var deposits-paused bool false)
(define-data-var withdrawals-paused bool false)
(define-data-var rebalancing-paused bool false)
(define-data-var system-paused bool false)
(define-data-var pause-timestamp uint u0)
(define-data-var total-locked-deposits uint u0)
(define-data-var early-withdrawal-penalty uint u1000)

(define-map user-balances
    principal
    uint
)

(define-map strategies
    uint
    {
        name: (string-ascii 64),
        allocation: uint,
        total-allocated: uint,
        apy: uint,
        active: bool,
        last-rebalance: uint,
    }
)

(define-map strategy-deposits
    {
        strategy-id: uint,
        user: principal,
    }
    uint
)

(define-map time-locks
    principal
    {
        amount: uint,
        lock-period: uint,
        start-block: uint,
        end-block: uint,
        bonus-multiplier: uint,
    }
)

(define-map lock-periods
    uint
    {
        blocks: uint,
        bonus-multiplier: uint,
    }
)

(define-read-only (get-user-balance (user principal))
    (default-to u0 (map-get? user-balances user))
)

(define-read-only (get-total-deposited)
    (var-get total-deposited)
)

(define-read-only (get-total-shares)
    (var-get total-shares)
)

(define-read-only (get-user-share-percentage (user principal))
    (let (
            (user-balance (get-user-balance user))
            (global-total-shares (var-get total-shares))
        )
        (if (is-eq global-total-shares u0)
            u0
            (/ (* user-balance u10000) global-total-shares)
        )
    )
)

(define-read-only (get-strategy (strategy-id uint))
    (map-get? strategies strategy-id)
)

(define-read-only (get-strategy-allocation (strategy-id uint))
    (match (map-get? strategies strategy-id)
        strategy (get allocation strategy)
        u0
    )
)

(define-read-only (get-all-strategies)
    (let ((current-id (var-get next-strategy-id)))
        (map get-strategy (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10))
    )
)

(define-private (min
        (a uint)
        (b uint)
    )
    (if (< a b)
        a
        b
    )
)

(define-read-only (calculate-optimal-allocation (strategy-id uint))
    (let (
            (strategy (unwrap! (map-get? strategies strategy-id) u0))
            (apy (get apy strategy))
            (total-amount (var-get total-deposited))
        )
        (if (is-eq total-amount u0)
            u0
            (min (/ (* apy u100) u10000) u5000)
        )
    )
)

(define-read-only (get-rebalancing-status)
    (var-get rebalancing-enabled)
)

(define-read-only (get-management-fee)
    (var-get management-fee)
)

(define-read-only (get-performance-fee)
    (var-get performance-fee)
)

(define-read-only (get-deposits-paused)
    (var-get deposits-paused)
)

(define-read-only (get-withdrawals-paused)
    (var-get withdrawals-paused)
)

(define-read-only (get-rebalancing-paused)
    (var-get rebalancing-paused)
)

(define-read-only (get-system-paused)
    (var-get system-paused)
)

(define-read-only (get-pause-timestamp)
    (var-get pause-timestamp)
)

(define-read-only (is-operation-allowed (operation (string-ascii 20)))
    (if (var-get system-paused)
        false
        (if (is-eq operation "deposit")
            (not (var-get deposits-paused))
            (if (is-eq operation "withdraw")
                (not (var-get withdrawals-paused))
                (if (is-eq operation "rebalance")
                    (not (var-get rebalancing-paused))
                    true
                )
            )
        )
    )
)

(define-read-only (get-user-time-lock (user principal))
    (map-get? time-locks user)
)

(define-read-only (get-lock-period-info (period-id uint))
    (map-get? lock-periods period-id)
)

(define-read-only (get-total-locked-deposits)
    (var-get total-locked-deposits)
)

(define-read-only (get-early-withdrawal-penalty)
    (var-get early-withdrawal-penalty)
)

(define-read-only (is-lock-expired (user principal))
    (match (map-get? time-locks user)
        lock-info (>= stacks-block-height (get end-block lock-info))
        true
    )
)

(define-read-only (calculate-bonus-yield
        (user principal)
        (base-yield uint)
    )
    (match (map-get? time-locks user)
        lock-info (/ (* base-yield (get bonus-multiplier lock-info)) u10000)
        base-yield
    )
)

(define-read-only (get-remaining-lock-blocks (user principal))
    (match (map-get? time-locks user)
        lock-info (if (>= stacks-block-height (get end-block lock-info))
            u0
            (- (get end-block lock-info) stacks-block-height)
        )
        u0
    )
)

(define-public (deposit (amount uint))
    (let (
            (sender tx-sender)
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (not (var-get deposits-paused)) ERR_DEPOSITS_PAUSED)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set user-balances sender (+ current-balance amount))
        (var-set total-deposited (+ current-total amount))
        (var-set total-shares (+ current-shares amount))
        (try! (auto-allocate-deposit amount))
        (ok amount)
    )
)

(define-public (withdraw (amount uint))
    (let (
            (sender tx-sender)
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (not (var-get withdrawals-paused)) ERR_WITHDRAWALS_PAUSED)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (>= current-total amount) ERR_INSUFFICIENT_LIQUIDITY)
        (try! (withdraw-from-strategies amount))
        (try! (as-contract (stx-transfer? amount tx-sender sender)))
        (map-set user-balances sender (- current-balance amount))
        (var-set total-deposited (- current-total amount))
        (var-set total-shares (- current-shares amount))
        (ok amount)
    )
)

(define-public (add-strategy
        (name (string-ascii 64))
        (target-allocation uint)
        (initial-apy uint)
    )
    (let ((strategy-id (var-get next-strategy-id)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= target-allocation u10000) ERR_INVALID_AMOUNT)
        (asserts! (is-none (map-get? strategies strategy-id))
            ERR_STRATEGY_ALREADY_EXISTS
        )
        (map-set strategies strategy-id {
            name: name,
            allocation: target-allocation,
            total-allocated: u0,
            apy: initial-apy,
            active: true,
            last-rebalance: stacks-block-height,
        })
        (var-set next-strategy-id (+ strategy-id u1))
        (ok strategy-id)
    )
)

(define-public (update-strategy-apy
        (strategy-id uint)
        (new-apy uint)
    )
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set strategies strategy-id (merge strategy { apy: new-apy }))
        (ok true)
    )
)

(define-public (toggle-strategy (strategy-id uint))
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set strategies strategy-id
            (merge strategy { active: (not (get active strategy)) })
        )
        (ok true)
    )
)

(define-public (rebalance-strategies)
    (let ((total-amount (var-get total-deposited)))
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (not (var-get rebalancing-paused)) ERR_REBALANCING_PAUSED)
        (asserts! (var-get rebalancing-enabled) ERR_REBALANCING_DISABLED)
        (asserts! (> total-amount u0) ERR_INSUFFICIENT_LIQUIDITY)
        (try! (rebalance-strategy u1))
        (try! (rebalance-strategy u2))
        (try! (rebalance-strategy u3))
        (ok true)
    )
)

(define-public (set-rebalancing-enabled (enabled bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set rebalancing-enabled enabled)
        (ok true)
    )
)

(define-public (set-management-fee (fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= fee u1000) ERR_INVALID_AMOUNT)
        (var-set management-fee fee)
        (ok true)
    )
)

(define-public (collect-fees)
    (let (
            (total-amount (var-get total-deposited))
            (mgmt-fee (var-get management-fee))
            (fee-amount (/ (* total-amount mgmt-fee) u10000))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> fee-amount u0) ERR_INVALID_AMOUNT)
        (try! (as-contract (stx-transfer? fee-amount tx-sender CONTRACT_OWNER)))
        (var-set total-deposited (- total-amount fee-amount))
        (ok fee-amount)
    )
)

(define-public (pause-deposits)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set deposits-paused true)
        (var-set pause-timestamp stacks-block-height)
        (ok true)
    )
)

(define-public (unpause-deposits)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set deposits-paused false)
        (ok true)
    )
)

(define-public (pause-withdrawals)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set withdrawals-paused true)
        (var-set pause-timestamp stacks-block-height)
        (ok true)
    )
)

(define-public (unpause-withdrawals)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set withdrawals-paused false)
        (ok true)
    )
)

(define-public (pause-rebalancing)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set rebalancing-paused true)
        (var-set pause-timestamp stacks-block-height)
        (ok true)
    )
)

(define-public (unpause-rebalancing)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set rebalancing-paused false)
        (ok true)
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set system-paused true)
        (var-set deposits-paused true)
        (var-set withdrawals-paused true)
        (var-set rebalancing-paused true)
        (var-set pause-timestamp stacks-block-height)
        (ok true)
    )
)

(define-public (emergency-unpause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set system-paused false)
        (var-set deposits-paused false)
        (var-set withdrawals-paused false)
        (var-set rebalancing-paused false)
        (ok true)
    )
)

(define-public (emergency-withdraw (amount uint))
    (let (
            (sender tx-sender)
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (>= current-total amount) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (var-get system-paused) ERR_UNAUTHORIZED)
        (try! (withdraw-from-strategies amount))
        (try! (as-contract (stx-transfer? amount tx-sender sender)))
        (map-set user-balances sender (- current-balance amount))
        (var-set total-deposited (- current-total amount))
        (var-set total-shares (- current-shares amount))
        (ok amount)
    )
)

(define-public (deposit-with-time-lock
        (amount uint)
        (lock-period-id uint)
    )
    (let (
            (sender tx-sender)
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
            (period-info (unwrap! (map-get? lock-periods lock-period-id)
                ERR_INVALID_LOCK_PERIOD
            ))
            (lock-blocks (get blocks period-info))
            (bonus-multiplier (get bonus-multiplier period-info))
            (end-block (+ stacks-block-height lock-blocks))
        )
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (not (var-get deposits-paused)) ERR_DEPOSITS_PAUSED)
        (asserts! (is-none (map-get? time-locks sender)) ERR_LOCK_ALREADY_EXISTS)
        (try! (stx-transfer? amount sender (as-contract tx-sender)))
        (map-set user-balances sender (+ current-balance amount))
        (map-set time-locks sender {
            amount: amount,
            lock-period: lock-period-id,
            start-block: stacks-block-height,
            end-block: end-block,
            bonus-multiplier: bonus-multiplier,
        })
        (var-set total-deposited (+ current-total amount))
        (var-set total-shares (+ current-shares amount))
        (var-set total-locked-deposits (+ (var-get total-locked-deposits) amount))
        (try! (auto-allocate-deposit amount))
        (ok amount)
    )
)

(define-public (withdraw-locked-deposit)
    (let (
            (sender tx-sender)
            (lock-info (unwrap! (map-get? time-locks sender) ERR_NO_LOCKED_DEPOSIT))
            (locked-amount (get amount lock-info))
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
        )
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (>= stacks-block-height (get end-block lock-info))
            ERR_FUNDS_STILL_LOCKED
        )
        (asserts! (>= current-balance locked-amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (>= current-total locked-amount) ERR_INSUFFICIENT_LIQUIDITY)
        (try! (withdraw-from-strategies locked-amount))
        (try! (as-contract (stx-transfer? locked-amount tx-sender sender)))
        (map-delete time-locks sender)
        (map-set user-balances sender (- current-balance locked-amount))
        (var-set total-deposited (- current-total locked-amount))
        (var-set total-shares (- current-shares locked-amount))
        (var-set total-locked-deposits
            (- (var-get total-locked-deposits) locked-amount)
        )
        (ok locked-amount)
    )
)

(define-public (early-withdraw-locked-deposit)
    (let (
            (sender tx-sender)
            (lock-info (unwrap! (map-get? time-locks sender) ERR_NO_LOCKED_DEPOSIT))
            (locked-amount (get amount lock-info))
            (penalty-rate (var-get early-withdrawal-penalty))
            (penalty-amount (/ (* locked-amount penalty-rate) u10000))
            (withdrawal-amount (- locked-amount penalty-amount))
            (current-balance (get-user-balance sender))
            (current-total (var-get total-deposited))
            (current-shares (var-get total-shares))
        )
        (asserts! (not (var-get system-paused)) ERR_SYSTEM_PAUSED)
        (asserts! (not (var-get withdrawals-paused)) ERR_WITHDRAWALS_PAUSED)
        (asserts! (< stacks-block-height (get end-block lock-info))
            ERR_FUNDS_STILL_LOCKED
        )
        (asserts! (>= current-balance locked-amount) ERR_INSUFFICIENT_BALANCE)
        (asserts! (>= current-total withdrawal-amount) ERR_INSUFFICIENT_LIQUIDITY)
        (try! (withdraw-from-strategies withdrawal-amount))
        (try! (as-contract (stx-transfer? withdrawal-amount tx-sender sender)))
        (map-delete time-locks sender)
        (map-set user-balances sender (- current-balance locked-amount))
        (var-set total-deposited (- current-total locked-amount))
        (var-set total-shares (- current-shares locked-amount))
        (var-set total-locked-deposits
            (- (var-get total-locked-deposits) locked-amount)
        )
        (ok withdrawal-amount)
    )
)

(define-public (set-early-withdrawal-penalty (penalty uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (<= penalty u5000) ERR_INVALID_AMOUNT)
        (var-set early-withdrawal-penalty penalty)
        (ok true)
    )
)

(define-private (auto-allocate-deposit (amount uint))
    (let ((best-strategy (find-best-strategy)))
        (if (is-some best-strategy)
            (allocate-to-strategy (unwrap-panic best-strategy) amount)
            (ok true)
        )
    )
)

(define-private (find-best-strategy)
    (let (
            (strategy-1 (map-get? strategies u1))
            (strategy-2 (map-get? strategies u2))
            (strategy-3 (map-get? strategies u3))
        )
        (if (and (is-some strategy-1) (get active (unwrap-panic strategy-1)))
            (if (and (is-some strategy-2) (get active (unwrap-panic strategy-2)))
                (if (> (get apy (unwrap-panic strategy-1))
                        (get apy (unwrap-panic strategy-2))
                    )
                    (some u1)
                    (some u2)
                )
                (some u1)
            )
            (if (and (is-some strategy-2) (get active (unwrap-panic strategy-2)))
                (some u2)
                (if (and (is-some strategy-3) (get active (unwrap-panic strategy-3)))
                    (some u3)
                    none
                )
            )
        )
    )
)

(define-private (allocate-to-strategy
        (strategy-id uint)
        (amount uint)
    )
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
        (map-set strategies strategy-id
            (merge strategy { total-allocated: (+ (get total-allocated strategy) amount) })
        )
        (ok true)
    )
)

(define-private (withdraw-from-strategies (amount uint))
    (let ((remaining-amount amount))
        (try! (withdraw-from-strategy u1
            (min remaining-amount (get-strategy-balance u1))
        ))
        (try! (withdraw-from-strategy u2
            (min remaining-amount (get-strategy-balance u2))
        ))
        (try! (withdraw-from-strategy u3
            (min remaining-amount (get-strategy-balance u3))
        ))
        (ok true)
    )
)

(define-private (withdraw-from-strategy
        (strategy-id uint)
        (amount uint)
    )
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
        (if (> amount u0)
            (map-set strategies strategy-id
                (merge strategy { total-allocated: (- (get total-allocated strategy) amount) })
            )
            false
        )
        (ok true)
    )
)

(define-private (get-strategy-balance (strategy-id uint))
    (match (map-get? strategies strategy-id)
        strategy (get total-allocated strategy)
        u0
    )
)

(define-private (rebalance-strategy (strategy-id uint))
    (let (
            (strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND))
            (optimal-allocation (calculate-optimal-allocation strategy-id))
            (current-allocation (get total-allocated strategy))
            (total-amount (var-get total-deposited))
        )
        (if (get active strategy)
            (let ((target-amount (/ (* total-amount optimal-allocation) u10000)))
                (if (> target-amount current-allocation)
                    (let ((move-amount (- target-amount current-allocation)))
                        (unwrap-panic (move-funds-to-strategy strategy-id move-amount))
                        (map-set strategies strategy-id
                            (merge strategy {
                                total-allocated: target-amount,
                                last-rebalance: stacks-block-height,
                            })
                        )
                        (ok true)
                    )
                    (if (< target-amount current-allocation)
                        (let ((move-amount (- current-allocation target-amount)))
                            (unwrap-panic (move-funds-from-strategy strategy-id move-amount))
                            (map-set strategies strategy-id
                                (merge strategy {
                                    total-allocated: target-amount,
                                    last-rebalance: stacks-block-height,
                                })
                            )
                            (ok true)
                        )
                        (ok true)
                    )
                )
            )
            (ok true)
        )
    )
)

(define-private (move-funds-to-strategy
        (strategy-id uint)
        (amount uint)
    )
    (if (> amount u0)
        (ok true)
        (ok false)
    )
)

(define-private (move-funds-from-strategy
        (strategy-id uint)
        (amount uint)
    )
    (if (> amount u0)
        (ok true)
        (ok false)
    )
)

(map-set lock-periods u1 {
    blocks: u4320,
    bonus-multiplier: u10500,
})

(map-set lock-periods u2 {
    blocks: u12960,
    bonus-multiplier: u11500,
})

(map-set lock-periods u3 {
    blocks: u25920,
    bonus-multiplier: u13000,
})

(map-set lock-periods u4 {
    blocks: u52560,
    bonus-multiplier: u15000,
})

(map-set strategies u1 {
    name: "High Yield Strategy",
    allocation: u4000,
    total-allocated: u0,
    apy: u1200,
    active: true,
    last-rebalance: u0,
})

(map-set strategies u2 {
    name: "Stable Strategy",
    allocation: u3000,
    total-allocated: u0,
    apy: u800,
    active: true,
    last-rebalance: u0,
})

(map-set strategies u3 {
    name: "Conservative Strategy",
    allocation: u3000,
    total-allocated: u0,
    apy: u500,
    active: true,
    last-rebalance: u0,
})

(var-set next-strategy-id u4)
