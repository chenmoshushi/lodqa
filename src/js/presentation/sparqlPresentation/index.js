const createTable = require('./createTable')

const privateData = {}

class SparqlPresentation {
  onSparqlCount() {
    privateData.sparqlCount = 0
  }

  onSolution(data, domId) {
    const {
      sparql,
      solutions
    } = data

    // Count up even if without solutions
    privateData.sparqlCount++

    if (solutions.length === 0 && !privateData.verbose) {
      return
    }

    // Add a table to the dom tree
    $(`#${domId}`)
      .append(createTable(sparql, privateData.sparqlCount))

    // Enable syntax highlight of sparql
    /*global CodeMirror:true*/
    const sparqls = document.querySelectorAll(`#${domId} textarea`)
    CodeMirror
      .fromTextArea(sparqls[sparqls.length - 1], {
        mode: 'application/sparql-query',
        readOnly: true,
        hardwrap: true
      })
      .wrapParagraph(undefined, {
        column: 125
      })
  }

  setVerbose(value) {
    privateData.verbose = value
  }
}

module.exports = new SparqlPresentation
