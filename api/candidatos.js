module.exports = async function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const cargo = String(req.query.cargo || '');
  const numero = String(req.query.numero || '');

  if (!['1', '3', '5', '6', '7', '8'].includes(cargo) || !/^\d{1,5}$/.test(numero)) {
    return res.status(400).json({ error: 'Invalid cargo or candidate number' });
  }

  const apiUrl = new URL('https://colinha.sandrafaraj.com.br/api/candidatos');
  apiUrl.searchParams.set('cargo', cargo);
  apiUrl.searchParams.set('numero', numero);

  try {
    const upstreamResponse = await fetch(apiUrl, {
      headers: {
        Accept: 'application/json',
        Origin: 'https://colinha.sandrafaraj.com.br',
        Referer: 'https://colinha.sandrafaraj.com.br/',
        'User-Agent': 'Mozilla/5.0'
      },
      signal: AbortSignal.timeout(10000)
    });

    const data = await upstreamResponse.json();
    return res.status(upstreamResponse.status).json(data);
  } catch (error) {
    console.error('Candidate API request failed:', error);
    return res.status(502).json({ error: 'Candidate API is unavailable' });
  }
};