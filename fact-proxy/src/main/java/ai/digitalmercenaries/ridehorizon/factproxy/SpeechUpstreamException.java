package ai.digitalmercenaries.ridehorizon.factproxy;

final class SpeechUpstreamException extends UpstreamException {
    static final String RIDER_SAFE_MESSAGE = "Premium voice is temporarily unavailable.";

    private final ElevenLabsFailureCode failureCode;
    private final int upstreamStatus;

    SpeechUpstreamException(ElevenLabsFailureCode failureCode, int upstreamStatus) {
        this(failureCode, upstreamStatus, null);
    }

    SpeechUpstreamException(ElevenLabsFailureCode failureCode, int upstreamStatus, Throwable cause) {
        super(
                "ElevenLabs upstream failure status=" + upstreamStatus + " diagnosticCode=" + failureCode.wireCode(),
                cause
        );
        this.failureCode = failureCode;
        this.upstreamStatus = upstreamStatus;
    }

    String diagnosticCode() {
        return failureCode.wireCode();
    }

    int upstreamStatus() {
        return upstreamStatus;
    }
}
