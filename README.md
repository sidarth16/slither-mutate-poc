# `slither-mutate` PoC

100% test coverage ≠ correct behaviour.

This repository demonstrates how mutation testing using `slither-mutate` exposes blind spots in smart contract test suites.

👉 Full breakdown: https://medium.com/@sidarths/100-test-coverage-felt-safe-slither-mutate-proved-me-wrong-0f956c239fb6

---

## Run the PoC

### Install latest Slither
pip install --no-cache-dir git+https://github.com/crytic/slither.git

### Run mutation testing
slither-mutate src --test-cmd "forge test" --test-dir test --contract-names SimpleVault -v

---

## Results

SimpleVault: 12 survivors  
SimpleVaultFixed: 1 survivor

---

## Key Insight

Coverage shows what runs.  
Mutation testing shows what tests actually catch.

---

## Author

Sidarth S
