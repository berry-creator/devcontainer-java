FROM debian:bookworm
USER root

#region Add basic packages
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        procps inetutils-ping telnet neovim jq exiftool libxml2-utils zsh \
        git curl wget tar gzip zip mariadb-client \
        ca-certificates sudo locales chromium \
    && apt-get autoremove -y && apt-get clean -y \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen \
    && ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo "${TZ}" > /etc/timezone && dpkg-reconfigure tzdata
#endregion

#region Set up a new user for development
ARG USERNAME=dev
ARG HOME="/home/${USERNAME}"
RUN useradd -g users -s /bin/zsh -m "${USERNAME}" \
    && usermod -aG sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
#endregion

#region Normal config for nvim, and fix neovim compatible issue with vscode extension, see https://github.com/vscode-neovim/vscode-neovim/wiki/Version-Compatibility-Notes
RUN mkdir -p ${HOME}/.config/nvim \
    && { \
        echo "set shortmess+=s"; \
        echo "imap jj <Esc> "; \
        echo 'let mapleader=" "'; \
        echo "nmap <leader>w :w"; \
        echo "nmap <leader>q :q"; \
        echo "nmap <leader>wq :wq"; \
    } > ${HOME}/.config/nvim/init.vim
#endregion

#region Install oh-my-zsh and some plugins
RUN curl -o- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

SHELL [ "/bin/zsh", "-c" ]
RUN source ~/.zshrc \
    && omz theme set ys \
    && omz plugin enable zsh-syntax-highlighting \
    && omz plugin enable zsh-autosuggestions
#endregion

#region Add additional PATH
USER ${USERNAME}
RUN sed -i '3i\export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH' ~/.zshrc
#endregion

#region Add custom functions
USER ${USERNAME}
RUN cat << 'EOF' >> ~/.zshrc

install_claude() {
  set -e

  if command -v claude >/dev/null 2>&1; then
    echo "✓ Claude CLI already installed, skipping installation"
    return 0
  fi

  echo "▶ Installing Claude CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
  echo "✓ Claude CLI ready, type command 'claude' to start using it"
}
EOF
#endregion

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

#region Install claude cli if needed
ARG CLAUDE_PREINSTALLED=false
USER ${USERNAME}
RUN if [ "${CLAUDE_PREINSTALLED}" = "true" ]; then \
      echo "==> CLAUDE_PREINSTALLED is set to true, installing Claude CLI..." \
      && source ~/.zshrc \
      && install_claude; \
    fi
#endregion


# Switch to dev user
USER ${USERNAME}
WORKDIR /home/${USERNAME}/workspace

ENTRYPOINT [ "/bin/zsh" ]
