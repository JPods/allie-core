#!/usr/bin/env python3
"""
wc_mcp_server.py — WebClerk MCP server for Claude Code

Exposes Alice's wcapi as Claude Code tools so Claude can query live WebClerk
data without copy-paste. Uses the same token infrastructure as allie_wc_client.py.

Tools:
  wc_search        — search any model (Contact, Invoice, Item, Order, ...)
  wc_get_contact   — find a contact by name or id
  wc_get_invoice   — get invoice + lines by id or contact
  wc_get_item      — find a product/service item by SKU or name
  wc_add_note      — add an AI coordination note (log, pending, config_suggestion)
  wc_jpods_stations — list available JPods stations and route pairs
  wc_jpods_price   — get personalized trip price (requires myCarryOn token)
  wc_jpods_travel  — dispatch a JPods trip (posts invoice + dispatches pod)

Registration in ~/.claude/settings.json:
  {
    "mcpServers": {
      "webclerk": {
        "command": "/Users/williamjames/Allie/.venv/bin/python",
        "args": ["/Users/williamjames/Allie/scripts/wc_mcp_server.py"]
      }
    }
  }

Run: /Users/williamjames/Allie/.venv/bin/python wc_mcp_server.py
"""

import sys
import json
import pathlib
import urllib.request
import urllib.error
from urllib.parse import urlencode

# Add scripts dir so we can import token helper
_SCRIPTS = pathlib.Path(__file__).parent
sys.path.insert(0, str(_SCRIPTS))

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("webclerk")

WC_BASE = "http://localhost:8000"


# ── Auth ───────────────────────────────────────────────────────────────────────

def _token() -> str:
    """Get a valid Bearer token for the 'claude' agent."""
    try:
        from allie_wc_token import get_token
        return get_token("claude")
    except Exception as e:
        raise RuntimeError(f"Cannot get WebClerk token: {e}. "
                           "Run allie_wc_token.py --setup to configure credentials.")


def _headers() -> dict:
    return {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {_token()}",
    }


def _get(path: str, params: dict | None = None) -> dict:
    url = f"{WC_BASE}{path}"
    if params:
        url += "?" + urlencode({k: v for k, v in params.items() if v is not None})
    req = urllib.request.Request(url, headers=_headers(), method="GET")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {body[:400]}")


def _post(path: str, payload: dict, token: str | None = None) -> dict:
    hdrs = _headers() if token is None else {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }
    data = json.dumps(payload).encode()
    req = urllib.request.Request(f"{WC_BASE}{path}", data=data, headers=hdrs, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {body[:400]}")


# ── Tools ──────────────────────────────────────────────────────────────────────

@mcp.tool()
def wc_search(
    model_name: str,
    search: str = "",
    filters: str = "",
    limit: int = 20,
) -> str:
    """Search any WebClerk model.

    Args:
        model_name: Model to query — Contact, Invoice, Item, Order, Customer, Document, Action, Project, ...
        search: Free-text search string (searches name/title fields).
        filters: JSON string of field filters e.g. '{"is_active": true, "kind": "service"}'.
        limit: Maximum records to return (default 20, max 100).
    """
    params: dict = {"model_name": model_name, "limit": min(limit, 100)}
    if search:
        params["search"] = search
    if filters:
        try:
            f = json.loads(filters)
            params.update(f)
        except json.JSONDecodeError:
            return f"Error: filters must be valid JSON. Got: {filters!r}"

    try:
        result = _get("/wcapi/get/", params)
        data = result.get("data") or result.get("results") or result
        count = result.get("count", len(data) if isinstance(data, list) else "?")
        return json.dumps({"count": count, "data": data}, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_get_contact(
    name: str = "",
    contact_id: int = 0,
    email: str = "",
) -> str:
    """Find a WebClerk contact by name, id, or email.

    Args:
        name: Full or partial name to search.
        contact_id: Exact contact id.
        email: Email address to search.
    """
    try:
        if contact_id:
            result = _get(f"/wcapi/get/Contact/", {"id": contact_id})
        elif email:
            result = _get("/wcapi/get/", {"model_name": "Contact", "email": email, "limit": 5})
        elif name:
            result = _get("/wcapi/get/", {"model_name": "Contact", "search": name, "limit": 10})
        else:
            return "Error: provide name, contact_id, or email"

        data = result.get("data") or result.get("results") or result
        return json.dumps(data, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_get_invoice(
    invoice_id: int = 0,
    contact_id: int = 0,
    limit: int = 10,
) -> str:
    """Get invoice(s) from WebClerk/Alice.

    Args:
        invoice_id: Specific invoice id.
        contact_id: Return invoices for this contact.
        limit: Max invoices to return when searching by contact (default 10).
    """
    try:
        if invoice_id:
            result = _get("/wcapi/get/Invoice/", {"id": invoice_id})
        elif contact_id:
            result = _get("/wcapi/get/", {
                "model_name": "Invoice",
                "contact_id": contact_id,
                "limit": limit,
                "ordering": "-dt_created",
            })
        else:
            return "Error: provide invoice_id or contact_id"

        data = result.get("data") or result.get("results") or result
        return json.dumps(data, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_get_item(
    sku: str = "",
    name: str = "",
    kind: str = "",
    limit: int = 20,
) -> str:
    """Find a WebClerk Item (product, service, or component).

    Args:
        sku: Exact or partial SKU. JPods trips use JPODS-{NETWORK}-{ORIGIN}-{DESTINATION}.
        name: Item name search.
        kind: Filter by kind — 'product', 'service', 'component'.
        limit: Max records (default 20).
    """
    params: dict = {"model_name": "Item", "limit": limit, "is_active": True}
    if sku:
        params["sku__icontains"] = sku
    if name:
        params["search"] = name
    if kind:
        params["kind"] = kind

    try:
        result = _get("/wcapi/get/", params)
        data = result.get("data") or result.get("results") or result
        count = result.get("count", len(data) if isinstance(data, list) else "?")
        return json.dumps({"count": count, "data": data}, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_add_note(
    body: str,
    category: str = "log",
    role: str = "system",
    for_agent: str = "",
) -> str:
    """Add an AI coordination note to WebClerk (alice_log / pending queue).

    Args:
        body: Note content.
        category: 'log' | 'pending' | 'config_suggestion' | 'keyword_gap'.
        role: 'system' | 'action_required' | 'config_suggestion'.
        for_agent: Target agent — 'allie', 'alice', or 'athena' (optional).
    """
    try:
        payload: dict = {"category": category, "role": role, "name": body, "details": {}}
        if for_agent:
            payload["details"]["for"] = for_agent
        result = _post("/wcapi/ai/note/", payload)
        return json.dumps(result, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_jpods_stations() -> str:
    """List available JPods stations and valid route pairs from WebClerk/Alice."""
    try:
        result = _get("/wcapi/jpods/ui/stations/")
        return json.dumps(result, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_jpods_identify(name_first: str) -> str:
    """Get a myCarryOn token for a JPods demo rider (Child, Adult, or Elderly).

    Args:
        name_first: 'Child', 'Adult', or 'Elderly'
    """
    try:
        result = _post("/wcapi/jpods/ui/identify/", {"name_first": name_first})
        return json.dumps(result, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_jpods_price(
    mycarryon_token: str,
    origin_station_id: str,
    destination_station_id: str,
) -> str:
    """Get a personalized JPods trip price.

    Args:
        mycarryon_token: Bearer token from wc_jpods_identify.
        origin_station_id: Origin station (e.g. 'S097').
        destination_station_id: Destination station (e.g. 'S098').
    """
    try:
        result = _post(
            "/wcapi/jpods/ui/price/",
            {"origin_station_id": origin_station_id, "destination_station_id": destination_station_id},
            token=mycarryon_token,
        )
        return json.dumps(result, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def wc_jpods_travel(
    mycarryon_token: str,
    origin_station_id: str,
    destination_station_id: str,
    price: str,
    currency: str,
    item_id: int,
    price_level: str = "retail",
    network: str = "sketchup",
) -> str:
    """Dispatch a JPods trip — posts invoice to Alice and sends pod to network.

    Args:
        mycarryon_token: Bearer token from wc_jpods_identify.
        origin_station_id: Origin station (e.g. 'S097').
        destination_station_id: Destination station (e.g. 'S098').
        price: Trip price as string (e.g. '2.00').
        currency: Currency code (e.g. 'USD').
        item_id: Item pk from wc_jpods_price response.
        price_level: 'retail' | 'wholesale' | 'sample'.
        network: Dispatch target — 'sketchup' | 'mesh-mobility' | 'physical'.
    """
    try:
        result = _post(
            "/wcapi/jpods/ui/travel/",
            {
                "origin_station_id": origin_station_id,
                "destination_station_id": destination_station_id,
                "price": price,
                "currency": currency,
                "item_id": item_id,
                "price_level": price_level,
                "dispatch_target": network,
            },
            token=mycarryon_token,
        )
        return json.dumps(result, indent=2, default=str)
    except Exception as e:
        return f"Error: {e}"


# ── Run ────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    mcp.run()
