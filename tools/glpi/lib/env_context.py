#!/usr/bin/env python3
"""Contexto / decorator de ambiente GLPI (prod|homolog).

Uso:
  from env_context import apply_glpi_env, with_glpi_env

  apply_glpi_env("homolog")  # seta os.environ a partir de ~/.secrets/glpi.env

  @with_glpi_env("homolog")
  def test_auth():
      ...
"""
from __future__ import annotations

import functools
import os
import re
from pathlib import Path
from typing import Any, Callable, TypeVar

F = TypeVar("F", bound=Callable[..., Any])

DEFAULT_SECRETS = Path.home() / ".secrets" / "glpi.env"
LEGACY_SECRETS = Path.home() / ".secrets" / "GLPI-tokens.txt"


def ensure_apirest(url: str) -> str:
    url = (url or "").rstrip("/")
    if not url:
        return url
    if not url.endswith("apirest.php"):
        url = f"{url}/apirest.php"
    return url


def parse_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        k, v = k.strip(), v.strip().strip('"').strip("'")
        if k:
            out[k] = v
    return out


def parse_legacy_pmf(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if re.search(r"pessoal\s+api-glpi", line, re.I):
            out["GLPI_USER_TOKEN"] = re.sub(r"\s+", "", line.split(":", 1)[1])
        elif re.search(r"grupo\s+api-glpi", line, re.I):
            out["GLPI_APP_TOKEN"] = re.sub(r"\s+", "", line.split(":", 1)[1])
        elif re.search(r"url-?\s*api\s*homolog", line, re.I):
            m = re.search(r"(https?://\S+)", line)
            if m:
                out["GLPI_API_URL_HOMOLOG"] = ensure_apirest(m.group(1))
        elif re.search(r"url-?\s*api\s*:", line, re.I) and "homolog" not in line.lower():
            m = re.search(r"(https?://\S+)", line)
            if m:
                out["GLPI_API_URL_PROD"] = ensure_apirest(m.group(1))
    return out


def resolve_secrets_path() -> Path:
    override = os.environ.get("GLPI_SECRETS_FILE", "").strip()
    if override:
        return Path(os.path.expanduser(override))
    if DEFAULT_SECRETS.is_file():
        return DEFAULT_SECRETS
    return LEGACY_SECRETS


def apply_glpi_env(env: str | None = None, *, secrets_file: str | Path | None = None) -> dict[str, str]:
    """Carrega secrets e aplica GLPI_* no os.environ conforme ambiente.

    Retorna dict resumido (sem tokens) para logs: {env, api_url, secrets_file}.
    """
    env_name = (env or os.environ.get("GLPI_ENV") or os.environ.get("GLPI_ENV_DEFAULT") or "prod").strip().lower()
    if env_name in ("hml", "homo", "homologacao", "homologação"):
        env_name = "homolog"
    if env_name not in ("prod", "production", "homolog"):
        raise ValueError(f"ambiente invalido: {env_name} (use prod|homolog)")
    if env_name == "production":
        env_name = "prod"

    path = Path(os.path.expanduser(str(secrets_file))) if secrets_file else resolve_secrets_path()
    data: dict[str, str] = {}
    if path.suffix == ".env" or path.name == "glpi.env":
        data = parse_dotenv(path)
    else:
        data = parse_legacy_pmf(path)
        # dotenv misturado?
        data.update({k: v for k, v in parse_dotenv(path).items() if k.startswith("GLPI_")})

    user = data.get("GLPI_USER_TOKEN") or data.get("USER_TOKEN") or os.environ.get("GLPI_USER_TOKEN", "")
    app = data.get("GLPI_APP_TOKEN") or data.get("APP_TOKEN") or os.environ.get("GLPI_APP_TOKEN", "")

    if env_name == "homolog":
        api = (
            os.environ.get("GLPI_API_URL_HOMOLOG")
            or data.get("GLPI_API_URL_HOMOLOG")
            or data.get("API_URL_HOMOLOG")
            or ""
        )
    else:
        api = (
            os.environ.get("GLPI_API_URL_PROD")
            or data.get("GLPI_API_URL_PROD")
            or data.get("API_URL_PROD")
            or data.get("GLPI_API_URL")
            or data.get("API_URL")
            or ""
        )

    # GLPI_API_URL explicito no ambiente do processo ainda vence se setado ANTES e env nao forçado?
    # Politica: apply_glpi_env sempre define a URL do ambiente pedido.
    api = ensure_apirest(api)

    if user:
        os.environ["GLPI_USER_TOKEN"] = user
    if app:
        os.environ["GLPI_APP_TOKEN"] = app
    if api:
        os.environ["GLPI_API_URL"] = api
    os.environ["GLPI_ENV"] = env_name
    os.environ["GLPI_SECRETS_FILE"] = str(path)
    if path.suffix == ".env" or path.name.endswith(".env"):
        os.environ.setdefault("GLPI_SECRETS_FORMAT", "dotenv")

    return {"env": env_name, "api_url": api, "secrets_file": str(path)}


def with_glpi_env(env: str = "homolog") -> Callable[[F], F]:
    """Decorator: executa a função com credenciais/URL do ambiente pedido."""

    def decorator(fn: F) -> F:
        @functools.wraps(fn)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            info = apply_glpi_env(env)
            print(
                f"[glpi-env] {info['env']} → {info['api_url']} (secrets: {info['secrets_file']})",
                flush=True,
            )
            return fn(*args, **kwargs)

        return wrapper  # type: ignore[return-value]

    return decorator


def state_suffix() -> str:
    """Sufixo de arquivo de state local para nao misturar prod/homolog."""
    env = (os.environ.get("GLPI_ENV") or "prod").lower()
    return ".homolog" if env == "homolog" else ""
