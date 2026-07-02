package ai.dml.motoguide.factproxy;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<Map<String, String>> handleBadRequest(BadRequestException ex) {
        log.warn("event=fact_request_rejected status=400 reason={}", ex.getMessage());
        return badRequest(ex.getMessage());
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> handleInvalidRequest(HttpMessageNotReadableException ex) {
        log.warn("event=fact_request_rejected status=400 reason={}", ex.getMessage());
        return badRequest("request body is invalid");
    }

    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<Map<String, String>> handleUnsupportedMediaType(HttpMediaTypeNotSupportedException ex) {
        log.warn("event=fact_request_rejected status=415 reason={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
                .body(Map.of("error", "contentType must be application/json"));
    }

    @ExceptionHandler(UpstreamException.class)
    public ResponseEntity<Map<String, String>> handleUpstream(UpstreamException ex) {
        log.warn("event=fact_request_upstream_failure status=502 reason={}", ex.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
                .body(Map.of("error", ex.getMessage()));
    }

    private ResponseEntity<Map<String, String>> badRequest(String message) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("error", message));
    }
}
