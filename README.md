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
