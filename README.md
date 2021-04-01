# SemanticSelectionGUI

Main repository for my CPSC 490 Project.

Prerequisites:
- macOS Big Sur
- A Swift toolchain
- [Stanford CoreNLP](https://stanfordnlp.github.io/CoreNLP/)

## Run
1. Start a CoreNLP server:
  - Using [CoreNLP itself](https://stanfordnlp.github.io/CoreNLP/download.html):
     ```sh
     java -mx4g -cp "*" edu.stanford.nlp.pipeline.StanfordCoreNLPServer -port 9000 -timeout 60000
     ```
  - Alternatively, you can use [stanza's CoreNLP client](https://stanfordnlp.github.io/stanza/corenlp_client.html) to manage a CoreNLP server
in python. Follow the instructions on the
website to install stanza and the CoreNLP client. A script to start a server could look like:
    ```python
    from stanza.server import CoreNLPClient

    with CoreNLPClient(
            annotators=['tokenize', 'ssplit', 'pos', 'parse'],
            endpoint='http://localhost:9000/') as nlp:
        while True:
            try:
                pass
            except KeyboardInterrupt:
                break
   
    ```
2. (Optional) Verify a server is running by opening <http://localhost:9000> in your browser.
3. Build and run the application:
    ```sh
    swift run
    ```
  By default, it looks for a server at `localhost:9000`. If you are a running a server with a
different endpoint, use
    ```sh
    swift run SemanticSelectionGUI --server <server address>
    ```
  After executing the command, a new window will open. You should be able to type text and make
selections as described below. Monitor the terminal window for any exceptions that might arise.

## Making selections

### Using the mouse

- Hold down the scroll wheel button
- Move the mouse to move the selection
- Use the scroll wheel to expand / shrink selection

### Using the trackpad

- Hold down the Command key
- Move the cursor to move selection
- Pinch out to expand selection, pinch in to shrink

