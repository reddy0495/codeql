/**
 * @name Failure to use HTTPS URLs
 * @description Non-HTTPS connections can be intercepted by third parties.
 * @kind path-problem
 * @problem.severity warning
 * @precision medium
 * @id cpp/non-https-url
 * @tags security
 *       external/cwe/cwe-319
 */

import cpp
import semmle.code.cpp.dataflow.TaintTracking
import DataFlow::PathGraph

/**
 * A string matching private host names of IPv4 and IPv6, which only matches
 * the host portion therefore checking for port is not necessary.
 * Several examples are localhost, reserved IPv4 IP addresses including
 * 127.0.0.1, 10.x.x.x, 172.16.x,x, 192.168.x,x, and reserved IPv6 addresses
 * including [0:0:0:0:0:0:0:1] and [::1]
 */
class PrivateHostName extends string {
  bindingset[this]
  PrivateHostName() {
    this.regexpMatch("(?i)localhost(?:[:/?#].*)?|127\\.0\\.0\\.1(?:[:/?#].*)?|10(?:\\.[0-9]+){3}(?:[:/?#].*)?|172\\.16(?:\\.[0-9]+){2}(?:[:/?#].*)?|192.168(?:\\.[0-9]+){2}(?:[:/?#].*)?|\\[?0:0:0:0:0:0:0:1\\]?(?:[:/?#].*)?|\\[?::1\\]?(?:[:/?#].*)?")
  }
}

/**
 * A string containing an HTTP URL not in a private domain.
 */
class HttpStringLiteral extends StringLiteral {
  HttpStringLiteral() {
    exists(string s | this.getValue() = s |
      s = "http"
      or
      exists(string tail |
        tail = s.regexpCapture("http://(.*)", 1) and not tail instanceof PrivateHostName
      ) and
      not TaintTracking::localExprTaint(any(StringLiteral p |
          p.getValue() instanceof PrivateHostName
        ), this.getParent*())
    )
  }
}

/**
 * Taint tracking configuration for HTTP connections.
 */
class HttpStringToUrlOpenConfig extends TaintTracking::Configuration {
  HttpStringToUrlOpenConfig() { this = "HttpStringToUrlOpenConfig" }

  override predicate isSource(DataFlow::Node src) {
    // Sources are strings containing an HTTP URL not in a private domain.
    src.asExpr() instanceof HttpStringLiteral
  }

  override predicate isSink(DataFlow::Node sink) {
    // Sinks can be anything that demonstrates the string is likely to be
    // accessed as a URL, for example using it in a network access. Some
    // URLs are only ever displayed or used for data processing.
    exists(FunctionCall fc |
      fc.getTarget().hasGlobalOrStdName(["system", "gethostbyname", "getaddrinfo"]) and
      sink.asExpr() = fc.getArgument(0)
      or
      fc.getTarget().hasGlobalOrStdName(["send", "URLDownloadToFile", "URLDownloadToCacheFile"]) and
      sink.asExpr() = fc.getArgument(1)
      or
      fc.getTarget().hasGlobalOrStdName(["curl_easy_setopt", "getnameinfo"]) and
      sink.asExpr() = fc.getArgument(2)
      or
      fc.getTarget().hasGlobalOrStdName(["ShellExecute", "ShellExecuteA", "ShellExecuteW"]) and
      sink.asExpr() = fc.getArgument(3)
    )
  }
}

from
  HttpStringToUrlOpenConfig config, DataFlow::PathNode source, DataFlow::PathNode sink,
  HttpStringLiteral str
where
  config.hasFlowPath(source, sink) and
  str = source.getNode().asExpr()
select str, source, sink, "A URL may be constructed with the HTTP protocol."
