FROM letsdone/devcontainer-base:0.1.0-all
USER root

ARG USERNAME=dev
#region Install JDK and set up env
USER ${USERNAME}
ARG JDK_X86_64_DOWNLOAD_URL=https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-x64_bin.tar.gz
ARG JDK_AARCH64_DOWNLOAD_URL=https://download.java.net/java/GA/jdk21.0.2/f2283984656d49d69e91c558476027ac/13/GPL/openjdk-21.0.2_linux-aarch64_bin.tar.gz
RUN mkdir -p ~/apps && cd ~/apps \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then \
         JDK_URL=${JDK_X86_64_DOWNLOAD_URL}; \
       elif [ "$ARCH" = "aarch64" ]; then \
         JDK_URL=${JDK_AARCH64_DOWNLOAD_URL}; \
       else \
         echo "Unsupported architecture: $ARCH" && exit 1; \
       fi \
    && curl -O $JDK_URL \
    && tar -zxvf $(basename $JDK_URL) \
    && rm $(basename $JDK_URL) \
    && { \
        echo ""; \
        echo 'export JAVA_HOME=~/apps/jdk-21.0.2'; \
        echo 'export PATH=$JAVA_HOME/bin:$PATH'; \
    } >> ~/.zshrc \
    && source ~/.zshrc \
    && cat ~/.zshrc \
    && java --version \
    && echo "Java installation completed."

ENV JAVA_HOME=/home/${USERNAME}/apps/jdk-21.0.2
#endregion

#region Install Maven and set up env
USER ${USERNAME}
ARG MAVEN_DOWNLOAD_URL=https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
RUN mkdir -p ~/apps && cd ~/apps \
    && curl -O ${MAVEN_DOWNLOAD_URL} \
    && tar -zxvf apache-maven-3.9.9-bin.tar.gz \
    && rm apache-maven-3.9.9-bin.tar.gz \
    && { \
        echo ""; \
        echo 'export M2_HOME=~/apps/apache-maven-3.9.9'; \
        echo 'export PATH=$M2_HOME/bin:$PATH'; \
    } >> ~/.zshrc \
    && source ~/.zshrc \
    && mvn --version \
    && mkdir /home/${USERNAME}/.m2 \
    && chown -R ${USERNAME}:users /home/${USERNAME}/.m2

ENV M2_HOME=/home/${USERNAME}/apps/apache-maven-3.9.9
#endregion

#region Download palantir-java-format-all-deps for some ide extensions to work properly
USER ${USERNAME}
ARG PALANTIR_VERSION=2.84.0
RUN echo "==> Start to download palantir-java-format-all-deps-${PALANTIR_VERSION}.jar" \
    && curl -fsSL "https://github.com/berry-creator/palantir-java-format-all-deps/releases/download/${PALANTIR_VERSION}/palantir-java-format-all-deps-${PALANTIR_VERSION}.jar" -o "/home/${USERNAME}/palantir-java-format-all-deps-${PALANTIR_VERSION}.jar" \
    && echo "java -jar ~/palantir-java-format-all-deps-${PALANTIR_VERSION}.jar --format-javadoc \"\$@\"" > /home/${USERNAME}/palantir-cli.sh \
    && chmod +x /home/${USERNAME}/palantir-cli.sh \
    && echo "==> palantir-java-format-all-deps-${PALANTIR_VERSION}.jar downloaded and palantir-cli.sh created"
#endregion

#region Install Claude CLI if needed
ARG CLAUDE_PREINSTALLED=false
USER ${USERNAME}
RUN if [ "${CLAUDE_PREINSTALLED}" = "true" ]; then \
      echo "==> CLAUDE_PREINSTALLED is set to true, installing Claude CLI..." \
      && source ~/.zshrc \
      && install_claude; \
    fi
#endregion

#region Install Gemini CLI if needed
ARG GEMINI_PREINSTALLED=false
USER ${USERNAME}
RUN if [ "${GEMINI_PREINSTALLED}" = "true" ]; then \
      echo "==> GEMINI_PREINSTALLED is set to true, installing Gemini CLI..." \
      && source ~/.zshrc \
      && install_gemini_cli; \
    fi
#endregion

#region Install Codex CLI if needed
ARG CODEX_PREINSTALLED=false
USER ${USERNAME}
RUN if [ "${CODEX_PREINSTALLED}" = "true" ]; then \
      echo "==> CODEX_PREINSTALLED is set to true, installing Codex CLI..." \
      && source ~/.zshrc \
      && install_codex; \
    fi
#endregion

# Switch to dev user
USER ${USERNAME}
WORKDIR /home/${USERNAME}/workspace

ENTRYPOINT [ "/bin/zsh" ]
