# Using Local Models with Ralph 2.0

## Current Implementation

Ralph 2.0 uses **Aider** for local Ollama models and **Cursor Agent** for API models (Claude).

### Why This Approach?

- **Cursor Agent CLI** (`agent` command) doesn't support local Ollama models directly - it always uses the Cursor API
- **Aider** has built-in support for Ollama via `ollama/model-name` format
- This provides the best experience for local models without API costs

### Usage

```bash
# Use local Ollama model (uses Aider)
./convert-v2.sh editio --model local
./start-v2.sh editio --model local

# Use Claude API (uses Cursor Agent)
./convert-v2.sh editio --model claude
./start-v2.sh editio --model claude
```

## Alternative: Configuring Cursor IDE for Local Models

If you want to use Cursor IDE's built-in local model support (for manual use in the IDE), you can configure it as follows:

### Steps to Use Local LLM with Cursor IDE

1. **Run Local Server**: Install Ollama or LM Studio and run a coding model (e.g., Qwen Coder, Llama3)
2. **Expose Endpoint**: Ensure the server is accessible (e.g., `http://localhost:11434` for Ollama)
3. **Configure Cursor IDE**:
   - Open Cursor Settings > Models
   - Add a new model (e.g., `local-model`)
   - Click "Override OpenAI Base URL" and enter your local endpoint (e.g., `http://localhost:11434`)
   - Use any placeholder text for the API key if required
4. **Verify & Use**: Test the connection to ensure Cursor recognizes the local model

### Important Limitations

- **Feature Availability**: Local models typically only support chat and cmd+K (inline editing). Advanced features like Composer or Cursor Tab are often unavailable or do not function properly.
- **Performance**: The effectiveness of the agent depends heavily on the model size and hardware (e.g., 8B models may struggle with complex instructions).
- **Privacy**: While the LLM is local, Cursor may still index files on their servers, meaning true "offline-only" privacy might not be achieved without specific configurations.
- **Alternatives**: If local performance is insufficient, OpenRouter is a supported alternative for using various open-source models within Cursor.

## Future: Cursor Agent with Local Models

If Cursor Agent CLI gains support for local models in the future, we can update Ralph 2.0 to use it. Currently, the `agent` command doesn't expose options for local model configuration.

### Potential Implementation

If Cursor Agent adds support for:
- `--model` flag to specify local models
- `--base-url` flag to point to local Ollama endpoint
- Or environment variables for local model configuration

Then we could update `lib/cursor_agent.sh` to support local models directly.

## Current Recommendation

**For Ralph 2.0 automation**: Use `--model local` which uses Aider with Ollama (works well, no API costs)

**For manual Cursor IDE use**: Configure Cursor IDE settings as described above if you want to use local models in the IDE interface

## Related Files

- `convert-v2.sh` - Handles model selection and agent invocation
- `start-v2.sh` - Handles model selection and agent invocation
- `lib/cursor_agent.sh` - Cursor Agent integration (currently API-only)
- `config.sh` - Model configuration
