package ai.digitalmercenaries.ridehorizon.factproxy;

public class UpstreamException extends RuntimeException {
    enum Category {
        CONFIGURATION,
        TIMEOUT,
        PROVIDER,
        TOOL,
        OUTPUT
    }

    private final Category category;

    public UpstreamException(String message) {
        this(Category.PROVIDER, message);
    }

    public UpstreamException(String message, Throwable cause) {
        this(Category.PROVIDER, message, cause);
    }

    public UpstreamException(Category category, String message) {
        super(message);
        this.category = category;
    }

    public UpstreamException(Category category, String message, Throwable cause) {
        super(message, cause);
        this.category = category;
    }

    Category category() {
        return category;
    }
}
