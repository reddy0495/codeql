/**
 * @name Uncontrolled data used in network request
 * @description Making a network request with user-controlled data allows for request forgery attacks.
 * @kind path-problem
 * @problem.severity error
 * @security-severity 9.1
 * @precision medium
 * @id rb/request-forgery
 * @tags security
 *       external/cwe/cwe-918
 */

import ruby
import codeql.ruby.Concepts
import codeql.ruby.DataFlow
import codeql.ruby.TaintTracking
import codeql.ruby.dataflow.RemoteFlowSources
import codeql.ruby.security.ServerSideRequestForgeryQuery

from Configuration config, DataFlow::PathNode source, DataFlow::PathNode sink
where config.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "The URL of this request depends on $@.", source.getNode(),
  "a user-provided value"
