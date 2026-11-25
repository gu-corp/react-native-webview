package com.brave.adblock;

public class BlockerResult {
    /** The request should be blocked. */
    public boolean matched;
    /** An exception rule ({@code @@...}) matched. */
    public boolean exception;
    /** An {@code $important} rule matched; later engines need not be checked. */
    public boolean important;
    /** A {@code data:} URL to serve instead of the request ({@code $redirect}), or null. */
    public String redirect;
    /** The URL with parameters removed by {@code $removeparam}, or null. */
    public String rewrittenUrl;
}
