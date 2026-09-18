FROM n8nio/n8n:latest

# Listen on the standard n8n port
EXPOSE 5678

# Use the default start command
CMD ["n8n", "start"]
