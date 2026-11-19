// Piccolo server statico per le prove a schermo: serve una cartella come farebbe l'app (schema app://).
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, extname, posix } from 'node:path';

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.glb': 'model/gltf-binary', '.gltf': 'model/gltf+json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.ktx2': 'image/ktx2', '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav', '.css': 'text/css' };

export function serve(root, port = 0) {
  const srv = createServer(async (req, res) => {
    const path = posix.normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname)).replace(/^[/]+/, '');
    if (path.startsWith('..')) { res.writeHead(403); res.end(); return; }
    try {
      const data = await readFile(join(root, path || 'index.html'));
      res.writeHead(200, { 'Content-Type': TYPES[extname(path)] || 'application/octet-stream' }); res.end(data);
    } catch { res.writeHead(404); res.end(); }
  });
  return new Promise(r => srv.listen(port, '127.0.0.1', () => r({ url: `http://127.0.0.1:${srv.address().port}/`, close: () => srv.close() })));
}
