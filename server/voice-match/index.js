'use strict';

const http = require('http');
const { Server } = require('socket.io');

const PORT = Number(process.env.PORT || 3847);
const MATCH_WAIT_MS = 60_000;

const ICEBREAKERS = [
  'Describe a movie you watched recently that you felt disappointed about.',
  'Talk about a skill you would like to learn in the next year.',
  'Describe a place you would like to visit again and explain why.',
  'Talk about an advertisement that you remember well.',
  'Describe a difficult decision you once made.',
];

function randomTopic() {
  return ICEBREAKERS[Math.floor(Math.random() * ICEBREAKERS.length)];
}

function shortAnonLabel(socketId) {
  let h = 0;
  for (let i = 0; i < socketId.length; i++) {
    h = (h << 5) - h + socketId.charCodeAt(i);
    h |= 0;
  }
  const n = (Math.abs(h) % 9000) + 1000;
  return `匿名_${n}`;
}

const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end('ok');
    return;
  }
  res.writeHead(404);
  res.end();
});

const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] },
  transports: ['websocket', 'polling'],
});

/** @type {{ socket: import('socket.io').Socket, timeout: NodeJS.Timeout }[]} */
const queue = [];
/** @type {Map<string, string[]>} sessionId -> [socketIdA, socketIdB] */
const sessions = new Map();

function removeFromQueue(socket) {
  const i = queue.findIndex((e) => e.socket.id === socket.id);
  if (i >= 0) {
    clearTimeout(queue[i].timeout);
    queue.splice(i, 1);
  }
}

function clearSession(sessionId) {
  const ids = sessions.get(sessionId);
  if (!ids) return;
  sessions.delete(sessionId);
  for (const id of ids) {
    const s = io.sockets.sockets.get(id);
    if (s) {
      s.leave(sessionId);
      s.data.matchSessionId = null;
    }
  }
}

function tryPair() {
  if (queue.length < 2) return;
  const first = queue.shift();
  const second = queue.shift();
  clearTimeout(first.timeout);
  clearTimeout(second.timeout);

  const sessionId = `sess_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
  const topic = randomTopic();

  const a = first.socket;
  const b = second.socket;

  sessions.set(sessionId, [a.id, b.id]);
  a.join(sessionId);
  b.join(sessionId);
  a.data.matchSessionId = sessionId;
  b.data.matchSessionId = sessionId;

  const peerLabelForA = shortAnonLabel(b.id);
  const peerLabelForB = shortAnonLabel(a.id);

  a.emit('matched', {
    sessionId,
    isCaller: a.id < b.id,
    peerLabel: peerLabelForA,
    topic,
  });
  b.emit('matched', {
    sessionId,
    isCaller: b.id < a.id,
    peerLabel: peerLabelForB,
    topic,
  });
}

io.on('connection', (socket) => {
  socket.data.matchSessionId = null;

  socket.on('join_match', () => {
    removeFromQueue(socket);
    if (queue.some((e) => e.socket.id === socket.id)) return;

    const timeout = setTimeout(() => {
      removeFromQueue(socket);
      socket.emit('match_timeout');
    }, MATCH_WAIT_MS);

    queue.push({ socket, timeout });
    tryPair();
  });

  socket.on('cancel_match', () => {
    removeFromQueue(socket);
  });

  socket.on('webrtc_signal', (payload) => {
    const sid = socket.data.matchSessionId;
    if (!sid || !payload) return;
    socket.to(sid).emit('webrtc_signal', payload);
  });

  socket.on('hang_up', () => {
    const sid = socket.data.matchSessionId;
    if (!sid) return;
    socket.to(sid).emit('peer_hang_up');
    clearSession(sid);
  });

  socket.on('disconnect', () => {
    removeFromQueue(socket);
    const sid = socket.data.matchSessionId;
    if (sid) {
      socket.to(sid).emit('peer_disconnected');
      clearSession(sid);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`eunoia-voice-match listening on 0.0.0.0:${PORT}`);
});
