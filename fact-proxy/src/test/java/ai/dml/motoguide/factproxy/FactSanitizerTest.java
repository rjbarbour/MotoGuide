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
    void sanitizeRejectsInvitationsAndRouteAdvice() {
        assertNull(FactSanitizer.sanitize("You should visit the old market square."));
        assertNull(FactSanitizer.sanitize("Take the right turn at the junction."));
    }

    @Test
    void sanitizeRejectsExcessSentencesInShortMode() {
        assertNull(FactSanitizer.sanitize(
                "Stroud is in Gloucestershire. It is famous for wool. There is more history too.",
                FactMode.SHORT_FACTS
        ));
    }

    @Test
    void sanitizeRejectsExcessSentencesInLongMode() {
        assertNull(FactSanitizer.sanitize(
                "Stroud is in Gloucestershire. It is famous for wool. It has deep history.",
                FactMode.LONG_FACTS
        ));
    }

    @Test
    void sanitizeTruncatesLongFacts() {
        String longFact = "a".repeat(150);
        assertEquals(120, FactSanitizer.sanitize(longFact).length());
    }

    @Test
    void sanitizeAllowsLongFactsWithinLongModeBound() {
        String longFact = "a".repeat(300);
        assertEquals(280, FactSanitizer.sanitize(longFact, FactMode.LONG_FACTS).length());
    }
}
