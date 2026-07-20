---
name: backup
description: "Use para backup/copia de seguranca do repositorio (backup completo, gerar backup, salvar backup). Nao use para documentar, auditar docs ou encerrar sessao."
argument-hint: "Opcional: commit/push antes do backup."
---

# Backup Skill

Objetivo: gerar backup completo com versionamento opcional, usando formato de compactacao mais eficiente por sistema operacional.

## Fluxo padrao (baixo custo de tokens)

1. Confirmar repositorio git e detectar origin com git remoto
2. Se houver alteracoes, perguntar uma unica vez sobre git add/commit/push.
3. Executar script nativo do ambiente:
   - Linux/WSL/macOS: `./scripts/backup.sh`
   - Windows: `./scripts/backup.ps1`
4. Reportar apenas resultado final: arquivo gerado + checksum + destino.

## Politica de compactacao

- Linux/WSL/macOS: usar `tar.gz` por padrao (mais rapido). Opcional `tar.xz` para maior compressao (`BACKUP_FORMAT=tar.xz`).
- Windows: usar `zip` por padrao.

## Fallback e instalacao de compactadores

- Linux/WSL/macOS: se faltar `tar`, `xz` ou `zip`, sugerir comando de instalacao do gerenciador detectado (apt, dnf, yum, pacman, zypper, brew).
- Windows: se faltar `Compress-Archive`, tentar `7z`; se ambos ausentes, sugerir `winget install 7zip.7zip`.

## Paths de destino

- Windows: `E:/VS-Win-Backup`
- WSL: `/mnt/e/VS-WSL-Backup`
- Outros hosts: `E:/VS-<host>-Backup`
- Override suportado: `BACKUP_ROOT`

## Variaveis suportadas

- `BACKUP_ROOT`: altera raiz do backup.
- `BACKUP_EXCLUDE`: lista separada por virgula de paths para excluir.
- `BACKUP_FORMAT`: `auto`|`tar.gz`|`tar.xz`|`zip` (principalmente para Linux/WSL).

## Comandos de uso

```bash
./scripts/backup.sh
BACKUP_FORMAT=tar.xz ./scripts/backup.sh
BACKUP_ROOT=/mnt/e/CustomBackup BACKUP_EXCLUDE=node_modules,.next ./scripts/backup.sh
```

```powershell
.\scripts\backup.ps1
$env:BACKUP_ROOT='E:\CustomBackup'; .\scripts\backup.ps1
```

## Boas praticas para eficiencia

- Evitar varreduras desnecessarias: nao ler docs extensos durante o backup.
- Responder com resumo curto (sem logs longos) apos execucao.
- Excluir artefatos volumosos (`node_modules`, `build`, `coverage`) quando nao forem necessarios para restauracao.

## Referencias

- Dicas: [DICAS_USO.md](DICAS_USO.md)
