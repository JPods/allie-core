#!/usr/bin/env python3
"""
Model Router — select the best LLM for each task.

Each agent/task type maps to the model that handles it best.
Fast model for quick questions, big model for deep synthesis,
reasoning model for validation, instruction model for coaching.

Usage:
    from model_router import route, generate

    model = route('reflection')      # → qwen2.5:72b
    model = route('quick_question')  # → gpt-oss:20b
    model = route('validation')      # → deepseek-r1:70b
    model = route('coaching')        # → llama3.3:70b

    response = generate('reflection', 'Synthesize today\'s events...')
"""
import argparse
import json
import sys

try:
    import ollama
    HAS_OLLAMA = True
except ImportError:
    HAS_OLLAMA = False


# Model registry — task type → model name
# Models are selected for their strengths, not their size
MODEL_REGISTRY = {
    # Deep synthesis, tool use, long context — Allie's primary brain
    'reflection': 'qwen2.5:72b',
    'synthesis': 'qwen2.5:72b',
    'cross_domain': 'qwen2.5:72b',
    'tool_use': 'qwen2.5:72b',
    'planning': 'qwen2.5:72b',

    # Fast general purpose — interactive daytime use
    'quick': 'gpt-oss:20b',
    'quick_question': 'gpt-oss:20b',
    'chat': 'gpt-oss:20b',
    'interactive': 'gpt-oss:20b',

    # Pure reasoning, math, logic chains — Noelle's domain
    'reasoning': 'deepseek-r1:70b',
    'validation': 'deepseek-r1:70b',
    'math': 'deepseek-r1:70b',
    'verification': 'deepseek-r1:70b',
    'audit': 'deepseek-r1:70b',

    # Instruction following, coaching, document generation — Alice's domain
    'coaching': 'llama3.3:70b',
    'training': 'llama3.3:70b',
    'documentation': 'llama3.3:70b',
    'instruction': 'llama3.3:70b',
    'report': 'llama3.3:70b',

    # Security review — Athena
    'security': 'athena:latest',
    'permission': 'athena:latest',
    'triage': 'athena-triage:latest',

    # Embeddings
    'embedding': 'nomic-embed-text:latest',
}

# Fallback chain — if preferred model unavailable
FALLBACK_CHAIN = {
    'qwen2.5:72b': ['gpt-oss:20b', 'llama3:latest'],
    'deepseek-r1:70b': ['deepseek-r1:8b', 'gpt-oss:20b'],
    'llama3.3:70b': ['llama3:latest', 'gpt-oss:20b'],
    'athena:latest': ['gpt-oss:20b'],
    'athena-triage:latest': ['athena:latest', 'gpt-oss:20b'],
}

# Agent → default task type mapping
AGENT_DEFAULTS = {
    'allie': 'reflection',
    'alice': 'coaching',
    'noelle': 'validation',
    'natalie': 'reasoning',
    'nora': 'quick',
    'sally': 'quick',
    'athena': 'security',
    'claude': 'synthesis',
}


def _available_models():
    """Get list of currently available Ollama models."""
    if not HAS_OLLAMA:
        return []
    try:
        models = ollama.list()
        return [m.model for m in models.models]
    except Exception:
        return []


def _is_available(model_name):
    """Check if a model is available locally."""
    available = _available_models()
    # Ollama list returns 'model:tag' format
    for m in available:
        if m == model_name or m.startswith(model_name.split(':')[0]):
            return True
    return False


def route(task_type, agent=None, require_available=True):
    """Route a task to the best model.

    Args:
        task_type: What kind of task ('reflection', 'quick', 'validation', etc.)
        agent: Agent name for default mapping ('allie', 'alice', etc.)
        require_available: If True, fall back if preferred model not available

    Returns: model name string
    """
    # If agent specified without task type, use agent default
    if agent and not task_type:
        task_type = AGENT_DEFAULTS.get(agent, 'quick')

    # Look up preferred model
    model = MODEL_REGISTRY.get(task_type, 'gpt-oss:20b')

    if require_available and not _is_available(model):
        # Try fallback chain
        for fallback in FALLBACK_CHAIN.get(model, []):
            if _is_available(fallback):
                return fallback
        # Last resort — gpt-oss:20b should always be available
        return 'gpt-oss:20b'

    return model


def generate(task_type, prompt, agent=None, system=None, **kwargs):
    """Route to the best model and generate a response.

    Args:
        task_type: Task type for routing
        prompt: The prompt to send
        agent: Optional agent name for default routing
        system: Optional system prompt
        **kwargs: Additional ollama.generate kwargs

    Returns: {model, response, task_type, eval_count, eval_duration}
    """
    if not HAS_OLLAMA:
        return {'error': 'ollama package not installed'}

    model = route(task_type, agent=agent)

    gen_kwargs = {'model': model, 'prompt': prompt}
    if system:
        gen_kwargs['system'] = system
    gen_kwargs.update(kwargs)

    try:
        response = ollama.generate(**gen_kwargs)
        return {
            'model': model,
            'task_type': task_type,
            'response': response.response,
            'eval_count': getattr(response, 'eval_count', 0),
            'eval_duration': getattr(response, 'eval_duration', 0),
        }
    except Exception as e:
        return {'model': model, 'task_type': task_type, 'error': str(e)}


def info():
    """Show routing table and model availability."""
    available = _available_models()

    print("Model Router — Task Routing Table\n")
    print(f"{'Task Type':<20} {'Model':<25} {'Available'}")
    print("-" * 60)

    seen = set()
    for task, model in sorted(MODEL_REGISTRY.items()):
        if model in seen:
            continue
        seen.add(model)
        avail = '✓' if any(m.startswith(model.split(':')[0]) for m in available) else '✗'
        tasks = [t for t, m in MODEL_REGISTRY.items() if m == model]
        print(f"{', '.join(tasks[:3]):<20} {model:<25} {avail}")

    print(f"\nAgent Defaults:")
    for agent, task in AGENT_DEFAULTS.items():
        model = MODEL_REGISTRY.get(task, '?')
        print(f"  {agent:<12} → {task:<16} → {model}")

    print(f"\n{len(available)} models available locally")


def main():
    parser = argparse.ArgumentParser(description="Model Router")
    parser.add_argument("command", choices=["route", "generate", "info"])
    parser.add_argument("args", nargs="*")
    parser.add_argument("--agent", default=None)
    parser.add_argument("--system", default=None)
    args = parser.parse_args()

    if args.command == "info":
        info()
    elif args.command == "route":
        task = args.args[0] if args.args else None
        model = route(task, agent=args.agent)
        print(model)
    elif args.command == "generate":
        if not args.args:
            print("Usage: model-router.py generate task_type 'prompt'")
            sys.exit(1)
        task = args.args[0]
        prompt = " ".join(args.args[1:])
        result = generate(task, prompt, agent=args.agent, system=args.system)
        if 'error' in result:
            print(f"Error: {result['error']}")
        else:
            print(f"[{result['model']}] {result['response']}")


if __name__ == "__main__":
    main()
