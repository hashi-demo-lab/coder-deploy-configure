FROM node:20

# Install essential packages
RUN apt-get update && apt-get install -y \
    git \
    less \
    sudo \
    curl \
    wget \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Configure npm global directory
RUN mkdir -p /usr/local/share/npm-global && \
    chown node:node /usr/local/share/npm-global && \
    npm config set prefix /usr/local/share/npm-global

ENV PATH="/usr/local/share/npm-global/bin:${PATH}"

# Install Oh My Zsh for the node user
USER node
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Set up working directory
RUN mkdir -p /workspace /home/node/.claude

# Configure sudo for node user
USER root
RUN echo "node ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/node-user && \
    chmod 0440 /etc/sudoers.d/node-user

# Switch back to node user
USER node

# Set zsh as default shell
ENV SHELL=/bin/zsh
WORKDIR /workspace

CMD ["/bin/zsh"]
