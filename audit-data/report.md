---
title: MathMasters Audit Report
author: César Escribano
date: January 31, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries MathMasters Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape César Escribano\par}
    \vfill
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: César Escribano [(@ceseshi)](https://github.com/ceseshi)

**Table of Contents**

- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
    - [\[H-1\] Incorrect input checking in mulWadUp may lead to calculation errors](#h-1-incorrect-input-checking-in-mulwadup-may-lead-to-calculation-errors)
    - [\[H-2\] Incorrect logic in mulWadUp may lead to calculation errors](#h-2-incorrect-logic-in-mulwadup-may-lead-to-calculation-errors)
  - [Medium](#medium)
    - [\[M-1\] Incorrect custom error signature in mulWad()](#m-1-incorrect-custom-error-signature-in-mulwad)
    - [\[M-2\] Incorrect custom error signature in mulWadUp()](#m-2-incorrect-custom-error-signature-in-mulwadup)
  - [Low](#low)
    - [\[L-1\] Contracts using Solidity version 0.8.3 will not compile](#l-1-contracts-using-solidity-version-083-will-not-compile)


# Protocol Summary

This is a security review of First Flight #8: Math Master, a public contest from [CodeHawks](https://www.codehawks.com/contests/clrp8xvh70001dq1os4gaqbv5).

This contract is a math library, optimized for gas efficiency.

# Disclaimer

The auditor makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the auditor is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

Repository

[https://github.com/Cyfrin/2024-01-math-master](https://github.com/Cyfrin/2024-01-math-master)

Commit Hash
```
84c149baf09c1558d7ba3493c7c4e68d83e7b3aa
```

## Scope

```
#-- MathMasters.sol
```

## Roles

# Executive Summary

This audit took place in January 2024, over 4 days, totalling 16 hours. The tools used were Visual Studio Code, Foundry and Halmos.

## Issues found

| Severity | Number of issues |
| -------- | ---------------- |
| High     | 2                |
| Medium   | 2                |
| Low      | 1                |
| Info     | 0                |
| Total    | 5                |

# Findings

## High

### [H-1] Incorrect input checking in mulWadUp may lead to calculation errors

**Relevant GitHub Links**

https://github.com/Cyfrin/2024-01-math-master/blob/84c149baf09c1558d7ba3493c7c4e68d83e7b3aa/src/MathMasters.sol#L52

**Summary**

The mulWadUp() function must check that the result of x * y will not overflow, but the condition is incorrect.

**Vulnerability Details**

The condition `if mul(y, gt(x, or(div(not(0), y), x)))` is incorrect, as it allows for x * y to overflow.

```javascript
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
@>          if mul(y, gt(x, or(div(not(0), y), x))) {
            mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

**Impact**

The function will return incorrect calculations, which may lead to loss of funds if used in monetary transactions.

**Tools Used**

Foundry, Manual review

**Proof of Concept**

This is a test that should revert, but it doesn't.

```javascript
function testMulWadUpOverflow1() public {
    uint256 y = 100;
    uint256 x = (type(uint256).max / y) + 1;
    uint256 r = MathMasters.mulWadUp(x, y);
    console2.log("r", r);
}
```

Test passes, confirming that the returned value did overflow.
```bash
forge test --mt testMulWadOverflow
...
[PASS] testMulWadUpOverflow1() (gas: 3775)
Logs:
  r 1
```

**Recommended Mitigation**

Correct the condition.

```diff
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
-           if mul(y, gt(x, or(div(not(0), y), x))) {
+           if mul(y, gt(x, div(not(0), y))) {
            mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

Test it:
```javascript
function testMulWadUpRevert() public {
    uint256 y = 100;
    uint256 x = (type(uint256).max / y) + 1;
    vm.expectRevert(0xa56044f7);
    uint256 r = MathMasters.mulWadUp(x, y);
    console2.log("r", r);
}
```

Test passes, confirming that the function reverted correctly.
```bash
forge test --mt testMulWadUpRevert

...
[PASS] testMulWadUpRevert() (gas: 3275)
```

### [H-2] Incorrect logic in mulWadUp may lead to calculation errors

**Relevant GitHub Links**

https://github.com/Cyfrin/2024-01-math-master/blob/84c149baf09c1558d7ba3493c7c4e68d83e7b3aa/src/MathMasters.sol#L56

**Summary**

The mulWadUp() function has a condition to check if `x / y == 1`, and in that case it adds 1 to x. This is unnecessary, and can lead to errors.

**Vulnerability Details**

The condition `if iszero(sub(div(add(z, x), y), 1))` checks if `x / y == 1`. This may have been added to adjust rounding upwards, but it is unnecessary and for big numbers may cause errors and overflows.

```javascript
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
        if mul(y, gt(x, div(not(0), y))) {
            mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
@>      if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

**Impact**

The function will return incorrect calculations, which may lead to loss of funds if used in monetary transactions.

**Tools Used**

Foundry, Halmos, Manual review

**Proof of Concept**

This test should pass but will fail.

```javascript
function testMulWadUpOverflow2() public {
    uint256 x2 = 149453833408801632100269689951836288089;
    uint256 y2 = 79700981937175649427451356571001433277;
    assertEq(MathMasters.mulWadUp(x2, y2), (x2 * y2 - 1) / 1e18 + 1);
}
```

This test will overflow.
```javascript
function testMulWadUpOverflow3() public {
    uint256 y = MathMasters.sqrt(type(uint256).max);
    uint256 x = type(uint256).max / y + 1;
    uint256 r = MathMasters.mulWadUp(x, y);
    console2.log("r", r);
}
```

```bash
forge test --mt testMulWadUpOverflow2
...

[FAIL. Reason: assertion failed] testMulWadUpOverflow2() (gas: 15259)
Logs:
  Error: a == b not satisfied [uint]
        Left: 11911617276956557497108380364885387729253693854339561184817
       Right: 11911617276956557497108380364885387729173992872402385535389
...

```bash
forge test --mt testMulWadUpOverflow3

[PASS] testMulWadUpOverflow3() (gas: 3788)
Logs:
  r 680564733841876926927
```

**Recommended Mitigation**

Remove the incorrect line.

```diff
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if mul(y, gt(x, div(not(0), y))) {
            mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
-       if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

Previous test passes, confirming that the mitigation is correct.
```bash
forge test --mt testMulWadUpOverflow2
...

[PASS] testMulWadUpOverflow2() (gas: 681)
```


## Medium

### [M-1] Incorrect custom error signature in mulWad()

**Relevant GitHub Links**

https://github.com/Cyfrin/2024-01-math-master/blob/84c149baf09c1558d7ba3493c7c4e68d83e7b3aa/src/MathMasters.sol#L40

**Summary**

The mulWad() function has a condition where it reverts with a custom error, but the returned signature is incorrect.

**Vulnerability Details**

According to the documentation, the custom error should be MathMasters__MulWadFailed() with signature 0xa56044f7, but the returned signature is 0xbac65e5b, which corresponds to MulWadFailed()

Also, the memory location where it is being stored is incorrect (0x40), as the revert is returning the last 4 bytes of the first word, so the returned signature is finally 0x00000000.

```javascript
function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
        if mul(y, gt(x, div(not(0), y))) {
@>              mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        z := div(mul(x, y), WAD)
    }
}
```

**Impact**

Dapps or contracts that interact with the contract implementing this library will get incorrect information about the error, and may malfunction.

**Tools Used**

Foundry, Manual review

**Proof of Concept**

This is a test that triggers the revert and expects the custom error signature 0xa56044f7.

```javascript
function testMulWadRevert() public {
    uint256 x = type(uint256).max / 2;
    uint256 y = 100;
    vm.expectRevert(0x00000000);
    uint256 r = MathMasters.mulWad(x, y);
}
```
Test passes, confirming that the returned signature is empty.
```bash
forge test --mt testMulWadRevert
...

[PASS] testMulWadRevert() (gas: 3197)
```

**Recommended Mitigation**

Correct the custom error and memory location.

```diff
function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
        if mul(y, gt(x, div(not(0), y))) {
-           mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
+           mstore(0x00, 0xa56044f7) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        z := div(mul(x, y), WAD)
    }
}
```

### [M-2] Incorrect custom error signature in mulWadUp()

**Relevant GitHub Links**

https://github.com/Cyfrin/2024-01-math-master/blob/84c149baf09c1558d7ba3493c7c4e68d83e7b3aa/src/MathMasters.sol#L53

**Summary**

The mulWadUp() function has a condition where it reverts with a custom error, but the returned signature is incorrect.

**Vulnerability Details**

According to the documentation, the custom error should be MathMasters__MulWadFailed() with signature 0xa56044f7, but the returned signature is 0xbac65e5b, which corresponds to MulWadFailed()

Also, the memory location where it is being stored is incorrect (0x40), as the revert is returning the last 4 bytes of the first word, so the returned signature is finally 0x00000000.

```javascript
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
        if mul(y, gt(x, or(div(not(0), y), x))) {
@>              mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

**Impact**

Dapps or contracts that interact with the contract implementing this library will get incorrect information about the error, and may malfunction.

**Tools Used**

Foundry, Manual review

**Proof of Concept**

This is a test that triggers the revert and expects the custom error signature 0xa56044f7.

```javascript
function testMulWadUpRevert() public {
    uint256 x = type(uint256).max / 2;
    uint256 y = 100;
    vm.expectRevert(0x00000000);
    uint256 r = MathMasters.mulWadUp(x, y);
    assertEq(r, (x * y - 1) / 1e18 + 1);
}
```

Test passes, confirming that the returned signature is empty.
```bash
forge test --mt testMulWadRevert
...

[PASS] testMulWadUpRevert() (gas: 3197)
```

**Recommended Mitigation**

Correct the custom error and memory location.

```diff
function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
    /// @solidity memory-safe-assembly
    assembly {
        // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
        if mul(y, gt(x, div(not(0), y))) {
-           mstore(0x40, 0xbac65e5b) // `MathMasters__MulWadFailed()`.
+           mstore(0x00, 0xa56044f7) // `MathMasters__MulWadFailed()`.
            revert(0x1c, 0x04)
        }
        if iszero(sub(div(add(z, x), y), 1)) { x := add(x, 1) }
        z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
    }
}
```

## Low

### [L-1] Contracts using Solidity version 0.8.3 will not compile

**Relevant GitHub Links**

https://github.com/Cyfrin/2024-01-math-master/blob/84c149baf09c1558d7ba3493c7c4e68d83e7b3aa/src/MathMasters.sol#L3

**Summary**

The version pragma indicates that the library will be valid for versions 0.8.3 or higher and below 0.9.0, but it is not compatible with 0.8.3.

**Vulnerability Details**

The library is using custom errors, but that functionality was introduced in 0.8.4, so it will not compile with 0.8.3.

```javascript
// SPDX-License-Identifier: MIT
// @notice We intentionally want to leave this as floating point so others can use it as a library.
pragma solidity ^0.8.3;

```

**Impact**

Contracts that require Soldity 0.8.3 will not be able to use this library.

**Tools Used**

Manual review

**Proof of Concept**

Set the compiler version to 0.8.3 in the tests and try to run.

MathMasters.t.sol
```javascript
// SPDX-License-Identifier: MIT
// @notice We intentionally want to leave this as floating point so others can use it as a library.
pragma solidity 0.8.3;

```

```bash
forge test
...

Compiler run failed:
Error (2314): Expected ';' but got '('
  --> src/MathMasters.sol:14:41:
   |
14 |     error MathMasters__FactorialOverflow();
   |                                         ^
```

**Recommended Mitigation**

Change the version pragma to ^0.8.4 and indicate this change in the documentation.

MathMasters.sol
```diff
// SPDX-License-Identifier: MIT
// @notice We intentionally want to leave this as floating point so others can use it as a library.
-pragma solidity ^0.8.3;
+pragma solidity ^0.8.4;
```