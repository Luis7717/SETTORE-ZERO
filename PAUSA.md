# In pausa (19 novembre 2026)

Lavoro fermato perché il PC era a corto di memoria. Nessun merge o rebase in corso, nessun agente attivo,
server locali e Chrome di prova chiusi. Su `main` non è stato spinto niente di nuovo.

## Rami e stato

| Ramo | Cosa contiene | Stato |
|---|---|---|
| `main` | gioco + correzione inseguimenti (chi scappa è già nel corridoio) | stabile |
| `varr-minigun` | Varr/Kross/Marsh rifiniti, icona AK, Minigun mitica | su GitHub, da provare su iPhone |
| `mirini-porta-bauli` (parte da `varr-minigun`) | serratura moderna, "Ricomincia da capo", mirino per arma, cannocchiale del cecchino, bauli nelle corse | su GitHub, da provare su iPhone |
| `caricamento-a-pezzi` (worktree `../SETTORE-ZERO-pezzi`) | asset in `www/assets/`, caricamento a pezzi, schema `app://`, trasferimento salvataggi | build riuscita, release `settore-zero-ipa-prova`, da provare su iPhone |

Tutti i rami: 45 livelli provati in simulazione fino in fondo, 0 errori.

## Prossimo passo
1. Aspettare le prove di Luis su iPhone:
   - IPA di `mirini-porta-bauli`: Varr, Minigun, serratura, cecchino, mirini, bauli;
   - IPA `settore-zero-ipa-prova`: apertura, livelli, progressi ancora presenti.
2. Con il suo ok, unire `mirini-porta-bauli` (che contiene già `varr-minigun`) in `main`.
3. Poi unire `main` dentro `caricamento-a-pezzi`.
   Conflitti attesi in `menu.js`, `style.css`, `audio.js`, `armi-ambienti.js`, `index.html`.
   I nuovi script `porta.js`, `mirini.js` e `bauli-corsa.js` vanno tenuti; nessun nuovo modello in base64 da convertire.
   Rifare i 45 livelli e solo dopo l'ok di Luis su iPhone portare `caricamento-a-pezzi` su `main`.
4. Proposte in attesa di risposta:
   - rendere i livelli davvero fissi (oggi una parte della costruzione usa `Math.random`);
   - rimpicciolire il mirino del fucile a pompa se dà fastidio.
