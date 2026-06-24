const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Parser = require('rss-parser');
const axios = require('axios');
const he = require('he');

admin.initializeApp();
const db = admin.firestore();
const parser = new Parser({
  timeout: 10000,
  headers: {
    'User-Agent':
      'AgriVet News Aggregator/1.0 (agricultural disease monitoring)',
  },
  customFields: {
    item: [
      ['media:content', 'mediaContent'],
      ['media:thumbnail', 'mediaThumbnail'],
      ['enclosure', 'enclosure'],
    ],
  },
});

// ── News sources ─────────────────────────────────────────────────────────────

const NEWS_SOURCES = [
  {
    id: 'fao',
    name: 'FAO',
    fullName: 'UN Food & Agriculture Organization',
    url: 'https://www.fao.org/news/rss-feed/en/',
    category: 'crop',
    region: 'global',
    priority: 1,
    icon: 'fao',
  },
  {
    id: 'woah',
    name: 'WOAH',
    fullName: 'World Organisation for Animal Health',
    url: 'https://www.woah.org/en/feed/',
    category: 'livestock',
    region: 'global',
    priority: 1,
    icon: 'woah',
  },
  {
    id: 'reliefweb_agri',
    name: 'ReliefWeb',
    fullName: 'ReliefWeb — Agriculture Africa',
    url: 'https://reliefweb.int/updates/rss.xml?primary_country=2&theme=4600',
    category: 'alert',
    region: 'africa',
    priority: 2,
    icon: 'reliefweb',
  },
  {
    id: 'allafrica',
    name: 'AllAfrica',
    fullName: 'AllAfrica — Agriculture',
    url: 'https://allafrica.com/tools/headlines/rdf/agriculture/headlines.rdf',
    category: 'crop',
    region: 'africa',
    priority: 2,
    icon: 'allafrica',
  },
  {
    id: 'cgiar',
    name: 'CGIAR',
    fullName: 'CGIAR — Food & Agriculture Research',
    url: 'https://www.cgiar.org/feed/',
    category: 'crop',
    region: 'global',
    priority: 2,
    icon: 'cgiar',
  },
  {
    id: 'bdnews',
    name: 'Botswana Daily News',
    fullName: 'Botswana Daily News',
    url: 'http://www.bw.gov.bw/rss/',
    category: 'policy',
    region: 'botswana',
    priority: 1,
    icon: 'bdnews',
  },
  {
    id: 'sabc_agri',
    name: 'SABC News',
    fullName: 'SABC News — Agriculture',
    url: 'https://www.sabcnews.com/sabcnews/category/south-africa/economy/agriculture/feed/',
    category: 'livestock',
    region: 'southern_africa',
    priority: 2,
    icon: 'sabc',
  },
  {
    id: 'farmersweekly',
    name: "Farmer's Weekly",
    fullName: "Farmer's Weekly South Africa",
    url: 'https://www.farmersweekly.co.za/feed/',
    category: 'crop',
    region: 'southern_africa',
    priority: 2,
    icon: 'farmersweekly',
  },
];

// ── Agriculture keywords for relevance filtering ──────────────────────────────

const AGRICULTURE_KEYWORDS = [
  // Disease keywords
  'foot and mouth', 'fmd', 'lumpy skin', 'newcastle', 'avian influenza',
  'bird flu', 'african swine fever', 'disease outbreak', 'animal disease',
  'livestock disease', 'crop disease', 'plant disease', 'blight', 'rust',
  'mosaic virus', 'smut', 'mould', 'pest outbreak', 'locust',
  // General agriculture
  'agriculture', 'farming', 'livestock', 'cattle', 'poultry', 'crops',
  'harvest', 'drought', 'rainfall', 'food security', 'food production',
  'farmer', 'smallholder', 'veterinary', 'animal health', 'plant health',
  'sorghum', 'maize', 'watermelon', 'wheat', 'grain',
  // African/Botswana specific
  'botswana', 'southern africa', 'sub-saharan africa', 'sadc',
  'beef', 'beef export', 'dvs', 'ministry of agriculture',
  'auda-nepad', 'african union', 'food and agriculture',
];

// ── Category detection ────────────────────────────────────────────────────────

function detectCategory(title, content, sourceCategory) {
  const text = `${title} ${content}`.toLowerCase();

  const diseaseTerms = [
    'disease', 'outbreak', 'infection', 'virus', 'fmd', 'lumpy',
    'blight', 'pest', 'locust', 'avian', 'swine fever', 'alert',
  ];
  const cropTerms = [
    'crop', 'harvest', 'maize', 'sorghum', 'wheat', 'grain',
    'plant', 'seed', 'yield', 'drought', 'rainfall', 'irrigation',
  ];
  const livestockTerms = [
    'cattle', 'livestock', 'poultry', 'beef', 'dairy', 'animal',
    'veterinary', 'herd', 'flock', 'goat', 'sheep', 'pig',
  ];
  const policyTerms = [
    'ministry', 'government', 'policy', 'regulation', 'export',
    'ban', 'restriction', 'subsidy', 'programme', 'fund',
  ];
  const weatherTerms = [
    'weather', 'rainfall', 'drought', 'flood', 'climate', 'forecast',
    'rain', 'temperature', 'season',
  ];

  if (diseaseTerms.some((t) => text.includes(t))) return 'alert';
  if (weatherTerms.some((t) => text.includes(t))) return 'weather';
  if (livestockTerms.some((t) => text.includes(t))) return 'livestock';
  if (cropTerms.some((t) => text.includes(t))) return 'crop';
  if (policyTerms.some((t) => text.includes(t))) return 'policy';

  return sourceCategory;
}

// ── Relevance check ───────────────────────────────────────────────────────────

function isRelevant(title, content) {
  const text = `${title} ${content}`.toLowerCase();
  return AGRICULTURE_KEYWORDS.some((kw) => text.includes(kw.toLowerCase()));
}

// ── Clean HTML from text ──────────────────────────────────────────────────────

function cleanText(text) {
  if (!text) return '';
  return he
    .decode(text)
    .replace(/<[^>]*>/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 500);
}

// ── Extract image from RSS item ───────────────────────────────────────────────

function extractImage(item) {
  if (item.mediaContent?.['$']?.url) return item.mediaContent['$'].url;
  if (item.mediaThumbnail?.['$']?.url) return item.mediaThumbnail['$'].url;
  if (item.enclosure?.url) return item.enclosure.url;
  if (item['media:content']?.['$']?.url) return item['media:content']['$'].url;
  return null;
}

// ── Fetch a single RSS source ─────────────────────────────────────────────────

async function fetchSource(source) {
  try {
    const feed = await parser.parseURL(source.url);
    const articles = [];

    for (const item of feed.items.slice(0, 20)) {
      const title = cleanText(item.title || '');
      const content = cleanText(
        item.contentSnippet || item.content || item.summary || ''
      );

      if (!title) continue;
      if (!isRelevant(title, content)) continue;

      const pubDate = item.pubDate
        ? new Date(item.pubDate)
        : new Date();

      // Skip articles older than 7 days
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
      if (pubDate < sevenDaysAgo) continue;

      const category = detectCategory(title, content, source.category);
      const imageUrl = extractImage(item);

      articles.push({
        id: `${source.id}_${Buffer.from(item.link || title).toString('base64').slice(0, 20)}`,
        title,
        summary: content,
        url: item.link || '',
        imageUrl: imageUrl || null,
        source: source.name,
        sourceFull: source.fullName,
        sourceIcon: source.icon,
        category,
        region: source.region,
        priority: source.priority,
        publishedAt: admin.firestore.Timestamp.fromDate(pubDate),
        fetchedAt: admin.firestore.Timestamp.now(),
      });
    }

    console.log(`✅ ${source.name}: fetched ${articles.length} relevant articles`);
    return articles;
  } catch (error) {
    console.error(`❌ ${source.name}: ${error.message}`);
    return [];
  }
}

// ── Save articles to Firestore ────────────────────────────────────────────────

async function saveArticles(articles) {
  if (articles.length === 0) return 0;

  const batch = db.batch();
  let count = 0;

  for (const article of articles) {
    const ref = db.collection('news').doc(article.id);

    // Check if article already exists to avoid overwriting
    const existing = await ref.get();
    if (!existing.exists) {
      batch.set(ref, article);
      count++;
    }
  }

  if (count > 0) await batch.commit();
  return count;
}

// ── Clean old articles ────────────────────────────────────────────────────────

async function cleanOldArticles() {
  const sevenDaysAgo = new Date();
  sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

  const old = await db
    .collection('news')
    .where(
      'publishedAt',
      '<',
      admin.firestore.Timestamp.fromDate(sevenDaysAgo)
    )
    .get();

  const batch = db.batch();
  old.docs.forEach((doc) => batch.delete(doc.ref));
  if (!old.empty) await batch.commit();

  console.log(`🗑️ Cleaned ${old.size} old articles`);
}

// ── Main scheduled function ───────────────────────────────────────────────────

exports.fetchAgriNews = functions
  .runWith({ timeoutSeconds: 120, memory: '256MB' })
  .pubsub.schedule('every 30 minutes')
  .onRun(async (context) => {
    console.log('🌾 AgriVet news fetch started');

    try {
      // Fetch all sources in parallel
      const results = await Promise.allSettled(
        NEWS_SOURCES.map((source) => fetchSource(source))
      );

      // Flatten all articles
      const allArticles = results
        .filter((r) => r.status === 'fulfilled')
        .flatMap((r) => r.value);

      // Remove duplicates by title similarity
      const seen = new Set();
      const unique = allArticles.filter((a) => {
        const key = a.title.toLowerCase().slice(0, 60);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });

      // Sort by priority then date
      unique.sort((a, b) => {
        if (a.priority !== b.priority) return a.priority - b.priority;
        return b.publishedAt.toDate() - a.publishedAt.toDate();
      });

      // Save to Firestore
      const saved = await saveArticles(unique);

      // Clean old articles
      await cleanOldArticles();

      console.log(`✅ Done: ${saved} new articles saved from ${unique.length} total fetched`);
    } catch (error) {
      console.error('❌ News fetch failed:', error);
    }
  });

// ── Manual trigger (HTTP) for testing ────────────────────────────────────────

exports.fetchAgriNewsNow = functions
  .runWith({ timeoutSeconds: 120, memory: '256MB' })
  .https.onRequest(async (req, res) => {
    // Simple auth check
    const token = req.headers['x-agrivet-token'];
    if (token !== functions.config().agrivet?.secret) {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    console.log('🌾 Manual news fetch triggered');

    try {
      const results = await Promise.allSettled(
        NEWS_SOURCES.map((source) => fetchSource(source))
      );

      const allArticles = results
        .filter((r) => r.status === 'fulfilled')
        .flatMap((r) => r.value);

      const seen = new Set();
      const unique = allArticles.filter((a) => {
        const key = a.title.toLowerCase().slice(0, 60);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });

      const saved = await saveArticles(unique);
      await cleanOldArticles();

      return res.json({
        success: true,
        fetched: unique.length,
        saved,
        sources: NEWS_SOURCES.map((s) => s.name),
      });
    } catch (error) {
      return res.status(500).json({ error: error.message });
    }
  });
