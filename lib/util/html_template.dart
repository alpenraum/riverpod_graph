String getHtmlTemplate() => '''
<!DOCTYPE html>
<html>

<head>
  <meta charset="utf-8">
  <title>Riverpod Graph</title>
  <script src="https://unpkg.com/cytoscape@3.24.0/dist/cytoscape.min.js"></script>
  <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>


  <style>
    html, body, #container {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
}

#cy {
  width: 100%;
  height: 100%;
  position: absolute;
  top: 0;
  left: 0;
}

#edge-info {
  position: absolute;
  top: 20px;
  right: 20px;
  background: rgba(255, 255, 255, 0.95);
  border: 1px solid #ccc;
  padding: 10px;
  border-radius: 8px;
  box-shadow: 0 2px 10px rgba(0,0,0,0.2);
  z-index: 10;
  display: none;
  max-width: 300px;
  font-family: sans-serif;
   overflow-wrap: break-word; /* Wrap long words */
  word-break: break-word;    /* Force breaking if needed */
  white-space: normal;       /* Allow text to wrap */
}
  </style>
</head>

<body>
<div id="container">
  <div id="cy"></div>
  <div id="edge-info"></div>
</div>
  <script>
    const graphData = {{graph}};

    const cy = cytoscape({
      container: document.getElementById('cy'),
      elements: graphData,
      layout: { name: 'breadthfirst' },
      style: [
        {
          selector: 'node',
          style: {
            'shape': 'roundrectangle',
            'label': 'data(label)',
            'text-valign': 'center',
            'padding': '10px',
            'color': '#fff',
            'background-color': '#007acc',
            'width': 'label',
            'height': 'label',
          }
        },
    {
  selector: 'edge',
  style: {
    'width': 2,
    'target-arrow-shape': 'triangle',
    'curve-style': 'bezier',
  }
},
        {
          selector: 'edge.watch',
          style: {
            'line-color': '#007acc',
            'target-arrow-color': '#007acc',
            'line-style': 'solid',
          }
        },
        {
          selector: 'edge.read',
          style: {
            'line-color': '#00b894',
            'target-arrow-color': '#00b894',
            'line-style': 'dashed',
          }
        },
        {
          selector: 'edge.listen',
          style: {
            'line-color': '#0D920F',
            'target-arrow-color': '#0D920F',
            'line-style': 'dotted',
          }
        },
        {
          selector: 'edge.highlighted',
          style: {
            'background-color': '#ff5e28',
            'line-color': '#ff5e28',
            'target-arrow-color': '#ff5e28',
            'width': 2,
            'z-index': 9999,
            'transition-property': 'background-color, line-color, target-arrow-color',
            'transition-duration': '300ms'
          }
        },
        {
          selector: 'edge.suppressed',
          style: {
            'line-color': '#ccc',
            'target-arrow-color': '#ccc',

            'width': 1,
            'transition-property': 'background-color, line-color, target-arrow-color',
            'transition-duration': '300ms'
          }
        },
        {
          selector: 'node.highlighted',
          style: {
            'background-color': '#ff5e28',
            'line-color': '#ff5e28',
            'target-arrow-color': '#ff5e28',
            'z-index': 9999,
            'transition-property': 'background-color, line-color, target-arrow-color',
            'transition-duration': '300ms'
          }
        },
        {
          selector: 'node.suppressed',
          style: {
            'line-color': '#ccc',
            'transition-property': 'background-color, line-color, target-arrow-color',
            'transition-duration': '300ms'
          }
        }
      ]
    });

    // Optional: highlight on click
    cy.on('tap', 'edge', function (evt) {
      const edge = evt.target;
      cy.edges().addClass('suppressed');
      edge.addClass('highlighted');
      edge.removeClass('suppressed');

      const type = edge.data('label') || '';
      const source = edge.data('source');
      const target = edge.data('target');
      const trace = edge.data('trace') || '';
const edgeInfoDiv = document.getElementById('edge-info');
      edgeInfoDiv.innerHTML = `
    <strong>Edge Selected</strong><br>
    <strong>From:</strong> \${source}<br>
    <strong>To:</strong> \${target}<br>
    <strong>Type:</strong> \${type}<br>
    <strong>Trace:</strong> <pre style="white-space:pre-wrap">\${trace}</pre>
  `;
  edgeInfoDiv.style.display = 'block';
    });

    cy.on('select', 'node', function (evt) {
      const node = evt.target;

      // Clear previous highlights
      cy.elements().removeClass('highlighted');
      cy.elements().addClass('suppressed');
      
      node.connectedEdges().addClass('highlighted');
      node.connectedEdges().removeClass('suppressed');

      // Highlight the node, its connected edges, and neighboring nodes
      const neighborhood = node.closedNeighborhood();
      neighborhood.addClass('highlighted');
    });

    cy.on('unselect', 'node', function () {
      cy.elements().removeClass('highlighted');
      cy.elements().removeClass('suppressed');
    });
    cy.on('unselect', 'edge', function () {
      cy.edges().removeClass('highlighted');
      cy.edges().removeClass('suppressed');
       const edgeInfoDiv = document.getElementById('edge-info');
       edgeInfoDiv.style.display = 'none';
    });

  </script>
</body>

</html>
 ''';
