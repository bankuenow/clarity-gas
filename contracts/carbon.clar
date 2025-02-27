;; clarity-gas: Carbon Credits Trading and Verification System
;; A contract for minting, trading, and retiring tokenized carbon credits
;; with automatic verification and transparent tracking

;; Contract owner
(define-data-var contract-owner principal tx-sender)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROJECT-EXISTS (err u101))
(define-constant ERR-PROJECT-NOT-FOUND (err u102))
(define-constant ERR-VERIFICATION-FAILED (err u103))
(define-constant ERR-INSUFFICIENT-CREDITS (err u104))
(define-constant ERR-CREDIT-ALREADY-RETIRED (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-INVALID-VERIFICATION-DATA (err u107))

;; Data structures

;; Project information - Stores details about carbon offset projects
(define-map projects
  { project-id: (string-ascii 32) }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-utf8 256),
    location: (string-ascii 64),
    methodology: (string-ascii 32),
    start-time: uint,
    end-time: uint,
    total-credits: uint,
    available-credits: uint,
    verification-status: bool,
    last-verified: uint
  }
)

;; Credit balances - Tracks who owns how many credits from which project
(define-map credit-balances
  { project-id: (string-ascii 32), owner: principal }
  { amount: uint }
)

;; Retired credits - Tracks credits that have been permanently retired
(define-map retired-credits
  { project-id: (string-ascii 32), retirement-id: (string-ascii 32) }
  {
    owner: principal,
    amount: uint,
    retirement-time: uint,
    beneficiary: (optional principal),
    retirement-reason: (string-utf8 128)
  }
)

;; Verification records - Stores verification data for projects
(define-map verification-records
  { project-id: (string-ascii 32), verification-id: (string-ascii 32) }
  {
    verifier: principal,
    timestamp: uint,
    methodology-version: (string-ascii 16),
    result: bool,
    emissions-reduced: uint,
    verification-data-hash: (buff 32),
    verification-report-url: (string-ascii 128)
  }
)

;; Public function to register a new carbon offset project
(define-public (register-project 
  (project-id (string-ascii 32))
  (name (string-ascii 64))
  (description (string-utf8 256))
  (location (string-ascii 64))
  (methodology (string-ascii 32))
  (start-time uint)
  (end-time uint)
  (total-credits uint))
  (let
    ((existing-project (map-get? projects { project-id: project-id })))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-project) ERR-PROJECT-EXISTS)
    (asserts! (> total-credits u0) ERR-INVALID-AMOUNT)
    (asserts! (< start-time end-time) ERR-INVALID-AMOUNT)
    
    (map-set projects
      { project-id: project-id }
      {
        owner: tx-sender,
        name: name,
        description: description,
        location: location,
        methodology: methodology,
        start-time: start-time,
        end-time: end-time,
        total-credits: total-credits,
        available-credits: total-credits,
        verification-status: false,
        last-verified: u0
      }
    )
    
    ;; Log the project registration
    (print { event: "project-registered", project-id: project-id, owner: tx-sender })
    (ok project-id)
  )
)

;; Function to submit verification data for a project
(define-public (verify-project
  (project-id (string-ascii 32))
  (verification-id (string-ascii 32))
  (methodology-version (string-ascii 16))
  (emissions-reduced uint)
  (verification-data-hash (buff 32))
  (verification-report-url (string-ascii 128)))
  (let
    ((project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
     (current-time (default-to u0 (get-block-info? time (- block-height u1)))))
    
    (asserts! (is-authorized-verifier tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= current-time (get start-time project)) ERR-INVALID-VERIFICATION-DATA)
    (asserts! (<= current-time (get end-time project)) ERR-INVALID-VERIFICATION-DATA)
    (asserts! (> emissions-reduced u0) ERR-INVALID-VERIFICATION-DATA)
    
    ;; Store verification record
    (map-set verification-records
      { project-id: project-id, verification-id: verification-id }
      {
        verifier: tx-sender,
        timestamp: current-time,
        methodology-version: methodology-version,
        result: true,
        emissions-reduced: emissions-reduced,
        verification-data-hash: verification-data-hash,
        verification-report-url: verification-report-url
      }
    )
    
    ;; Update project verification status
    (map-set projects
      { project-id: project-id }
      (merge project
        {
          verification-status: true,
          last-verified: current-time
        }
      )
    )
    
    ;; Log the verification event
    (print {
      event: "project-verified",
      project-id: project-id,
      verification-id: verification-id,
      verifier: tx-sender,
      emissions-reduced: emissions-reduced
    })
    
    (ok true)
  )
)

;; Mint new carbon credits (only for verified projects)
(define-public (mint-credits
  (project-id (string-ascii 32))
  (amount uint)
  (recipient principal))
  (let
    ((project (unwrap! (map-get? projects { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
     (current-balance (default-to { amount: u0 } (map-get? credit-balances { project-id: project-id, owner: recipient }))))
    
    ;; Check authorization and verification status
    (asserts! (is-eq tx-sender (get owner project)) ERR-NOT-AUTHORIZED)
    (asserts! (get verification-status project) ERR-VERIFICATION-FAILED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= amount (get available-credits project)) ERR-INSUFFICIENT-CREDITS)
    
    ;; Update balances
    (map-set credit-balances
      { project-id: project-id, owner: recipient }
      { amount: (+ (get amount current-balance) amount) }
    )
    
    ;; Update project available credits
    (map-set projects
      { project-id: project-id }
      (merge project
        { available-credits: (- (get available-credits project) amount) }
      )
    )
    
    ;; Log the minting event
    (print {
      event: "credits-minted",
      project-id: project-id,
      amount: amount,
      recipient: recipient
    })
    
    (ok amount)
  )
)

;; Transfer carbon credits between accounts
(define-public (transfer-credits
  (project-id (string-ascii 32))
  (amount uint)
  (recipient principal))
  (let
    ((sender-balance (unwrap! (map-get? credit-balances { project-id: project-id, owner: tx-sender }) ERR-INSUFFICIENT-CREDITS))
     (recipient-balance (default-to { amount: u0 } (map-get? credit-balances { project-id: project-id, owner: recipient }))))
    
    (asserts! (>= (get amount sender-balance) amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update sender balance
    (map-set credit-balances
      { project-id: project-id, owner: tx-sender }
      { amount: (- (get amount sender-balance) amount) }
    )
    
    ;; Update recipient balance
    (map-set credit-balances
      { project-id: project-id, owner: recipient }
      { amount: (+ (get amount recipient-balance) amount) }
    )
    
    ;; Log the transfer event
    (print {
      event: "credits-transferred",
      project-id: project-id,
      amount: amount,
      sender: tx-sender,
      recipient: recipient
    })
    
    (ok amount)
  )
)

;; Retire carbon credits permanently
(define-public (retire-credits
  (project-id (string-ascii 32))
  (amount uint)
  (retirement-id (string-ascii 32))
  (beneficiary (optional principal))
  (retirement-reason (string-utf8 128)))
  (let
    ((sender-balance (unwrap! (map-get? credit-balances { project-id: project-id, owner: tx-sender }) ERR-INSUFFICIENT-CREDITS))
     (current-time (default-to u0 (get-block-info? time (- block-height u1))))
     (existing-retirement (map-get? retired-credits { project-id: project-id, retirement-id: retirement-id })))
    
    (asserts! (is-none existing-retirement) ERR-CREDIT-ALREADY-RETIRED)
    (asserts! (>= (get amount sender-balance) amount) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update sender balance
    (map-set credit-balances
      { project-id: project-id, owner: tx-sender }
      { amount: (- (get amount sender-balance) amount) }
    )
    
    ;; Record retirement
    (map-set retired-credits
      { project-id: project-id, retirement-id: retirement-id }
      {
        owner: tx-sender,
        amount: amount,
        retirement-time: current-time,
        beneficiary: beneficiary,
        retirement-reason: retirement-reason
      }
    )
    
    ;; Log the retirement event
    (print {
      event: "credits-retired",
      project-id: project-id,
      retirement-id: retirement-id,
      amount: amount,
      owner: tx-sender,
      beneficiary: beneficiary
    })
    
    (ok amount)
  )
)

;; Administrative functions

;; List of authorized verifiers
(define-map authorized-verifiers principal bool)

;; Check if a principal is an authorized verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)

;; Add an authorized verifier (only contract owner)
(define-public (add-authorized-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set authorized-verifiers verifier true)
    (print { event: "verifier-added", verifier: verifier })
    (ok true)
  )
)

;; Remove an authorized verifier (only contract owner)
(define-public (remove-authorized-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-delete authorized-verifiers verifier)
    (print { event: "verifier-removed", verifier: verifier })
    (ok true)
  )
)

;; Transfer contract ownership
(define-public (transfer-contract-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (print { event: "ownership-transferred", new-owner: new-owner })
    (ok true)
  )
)

;; Read-only functions for querying contract state

;; Get project details
(define-read-only (get-project (project-id (string-ascii 32)))
  (map-get? projects { project-id: project-id })
)

;; Get credit balance for a specific owner and project
(define-read-only (get-credit-balance (project-id (string-ascii 32)) (owner principal))
  (default-to { amount: u0 } (map-get? credit-balances { project-id: project-id, owner: owner }))
)

;; Get retirement details
(define-read-only (get-retirement (project-id (string-ascii 32)) (retirement-id (string-ascii 32)))
  (map-get? retired-credits { project-id: project-id, retirement-id: retirement-id })
)

;; Get verification record
(define-read-only (get-verification-record (project-id (string-ascii 32)) (verification-id (string-ascii 32)))
  (map-get? verification-records { project-id: project-id, verification-id: verification-id })
)

;; Get the current contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)