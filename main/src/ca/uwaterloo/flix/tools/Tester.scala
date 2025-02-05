package ca.uwaterloo.flix.tools

import ca.uwaterloo.flix.language.ast.Symbol
import ca.uwaterloo.flix.runtime.CompilationResult
import ca.uwaterloo.flix.util.Formatter

/**
 * Evaluates all tests in a model.
 */
object Tester {

  /**
   * Represents the outcome of a single test.
   */
  sealed trait TestResult {
    /**
     * The symbol associated with the test.
     */
    def sym: Symbol.DefnSym
  }

  object TestResult {

    /**
     * Represents a successful test case.
     */
    case class Success(sym: Symbol.DefnSym, msg: String) extends TestResult

    /**
     * Represents a failed test case.
     */
    case class Failure(sym: Symbol.DefnSym, msg: String) extends TestResult

  }

  /**
   * Represents the outcome of a run of a suite of tests.
   */
  sealed trait OverallTestResult

  object OverallTestResult {

    /**
     * Represents the outcome where all tests succeeded.
     */
    case object Success extends OverallTestResult

    /**
     * Represents the outcome where at least one test failed.
     */
    case object Failure extends OverallTestResult

    /**
     * Represents the outcome where no tests were run.
     */
    case object NoTests extends OverallTestResult
  }

  /**
   * Represents the results of running all the tests in a given model.
   */
  case class TestResults(results: List[TestResult]) {
    def output(formatter: Formatter): String = {
      var success = 0
      var failure = 0
      val sb = new StringBuilder()
      for ((ns, tests) <- results.groupBy(_.sym.namespace)) {
        val namespace = if (ns.isEmpty) "root" else ns.mkString("/")
        sb.append(formatter.line("Tests", namespace) + System.lineSeparator())
        for (test <- tests.sortBy(_.sym.loc)) {
          test match {
            case TestResult.Success(sym, msg) =>
              sb.append("  " + formatter.green("✓") + " " + sym.name + System.lineSeparator())
              success = success + 1
            case TestResult.Failure(sym, msg) =>
              sb.append("  " + formatter.red("✗") + " " + sym.name + ": " + msg + " (" + formatter.blue(sym.loc.format) + ")" + System.lineSeparator())
              failure = failure + 1
          }
        }
        sb.append(System.lineSeparator())
      }
      // Summary
      if (failure == 0) {
        sb.append(formatter.green("  Tests Passed!") + s" (Passed: $success / $success)" + System.lineSeparator())
      } else {
        sb.append(formatter.red(s"  Tests Failed!") + s" (Passed: $success / ${success + failure})" + System.lineSeparator())
      }
      sb.toString()
    }

    def overallResult: OverallTestResult = {
      if (results.isEmpty) {
        OverallTestResult.NoTests
      } else if (results.forall(_.isInstanceOf[TestResult.Success])) {
        OverallTestResult.Success
      } else {
        OverallTestResult.Failure
      }
    }
  }

  /**
   * Evaluates all tests.
   *
   * Returns a pair of (successful, failed)-tests.
   */
  def test(compilationResult: CompilationResult): TestResults = {
    val results = compilationResult.getTests.toList.map {
      case (sym, defn) =>
        try {
          val result = defn()
          result match {
            case java.lang.Boolean.TRUE => TestResult.Success(sym, "Returned true.")
            case java.lang.Boolean.FALSE => TestResult.Failure(sym, "Returned false.")
            case _ => TestResult.Success(sym, "Returned non-boolean value.")
          }
        } catch {
          case ex: Exception =>
            TestResult.Failure(sym, ex.getMessage)
        }
    }
    TestResults(results)
  }

}
