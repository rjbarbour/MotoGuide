package ai.dml.motoguide.factproxy;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = false)
public record SpeechRequest(String text) {
    private static final int MAX_SPEECH_TEXT_LENGTH = 1400;

    public ValidatedSpeechRequest validateAndNormalize() {
        if (text == null || text.isBlank()) {
            throw new BadRequestException("text is required");
        }

        String normalized = text.trim().replaceAll("\\s+", " ");
        if (normalized.length() > MAX_SPEECH_TEXT_LENGTH) {
            throw new BadRequestException("text is too long");
        }

        return new ValidatedSpeechRequest(normalized);
    }
}

record ValidatedSpeechRequest(String text) {
}
