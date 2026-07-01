package ai.dml.motoguide.factproxy;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class FactSanitizerTest {

    @Test
    void sanitizeTrimsQuotesAndNewlines() {
        assertEquals(
                "Known for its wool trade.",
                FactSanitizer.sanitize("\"Known for its wool trade.\n\"")
        );
    }

    @Test
    void sanitizeRejectsQuestions() {
        assertNull(FactSanitizer.sanitize("Did you know Stroud has canals?"));
    }

    @Test
    void sanitizeTruncatesLongFacts() {
        String longFact = "a".repeat(150);
        assertEquals(120, FactSanitizer.sanitize(longFact).length());
    }
}
