# SemanticSelectionGUI

Main repository for my CPSC 490 Project.

Prerequisites:
- macOS Big Sur
- A Swift toolchain
- [Stanford CoreNLP](https://stanfordnlp.github.io/CoreNLP/)

To run:
1. Start a CoreNLP server at `http://localhost:9000/`:
     ```sh
     java -mx4g -cp "*" edu.stanford.nlp.pipeline.StanfordCoreNLPServer -port 9000 -timeout 60000
     ```
2. Build and run the application:
    ```sh
    swift run
    ```

# Making selections

## Using the mouse

- Hold down the scroll wheel button
- Move the mouse to move the selection
- Use the scroll wheel to expand / shrink selection

## Using the trackpad

- Hold down the Command key
- Move the cursor to move selection
- Pinch out to expand selection, pinch in to shrink

