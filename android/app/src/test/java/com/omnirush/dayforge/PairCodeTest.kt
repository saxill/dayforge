package com.omnirush.dayforge

import com.omnirush.dayforge.data.PairCode
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PairCodeTest {
    @Test
    fun acceptsOnlySixCharacterDayforgeCodes() {
        assertTrue(PairCode.isValid("ACDE23"))
        assertTrue(PairCode.isValid("MNPQRT"))
        assertFalse(PairCode.isValid("ACDE2"))
        assertFalse(PairCode.isValid("ACDE230"))
        assertFalse(PairCode.isValid("ACDEIO"))
        assertFalse(PairCode.isValid("acde23"))
    }
}
