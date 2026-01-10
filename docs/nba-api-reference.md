# NBA API Complete Reference Guide
## For NBA Oracle Project

**Created:** January 2026
**Purpose:** Comprehensive reference for building ML-powered NBA game predictions

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [API Options Comparison](#api-options-comparison)
3. [The nba_api Package (Primary Choice)](#the-nba_api-package)
4. [Alternative APIs](#alternative-apis)
5. [Cloud Hosting Warning](#cloud-hosting-warning)
6. [Key Endpoints for Your Project](#key-endpoints-for-your-project)
7. [Getting Today's Games](#getting-todays-games)
8. [Historical Data for ML Training](#historical-data-for-ml-training)
9. [ML Prediction Insights](#ml-prediction-insights)
10. [Code Examples](#code-examples)
11. [Rate Limiting & Best Practices](#rate-limiting--best-practices)
12. [Useful Resources](#useful-resources)

---

## Executive Summary

**TL;DR for NBA Oracle:**

| Need | Solution |
|------|----------|
| Today's games (live/scheduled) | `nba_api.live.nba.endpoints.scoreboard.ScoreBoard()` |
| Historical game data (for ML) | `nba_api.stats.endpoints.leaguegamefinder.LeagueGameFinder()` |
| Team stats by season | `nba_api.stats.endpoints.teamgamelog.TeamGameLog()` |
| Backup API (if rate limited) | balldontlie.io (requires free API key) |
| **Critical Warning** | stats.nba.com **BLOCKS cloud providers** (AWS, Heroku, etc.) |

**Your Development Strategy:**
1. **Local dev:** Use `nba_api` directly — works perfectly
2. **Production:** Either use a proxy service OR use balldontlie API OR pre-cache data locally and upload

---

## API Options Comparison

### Free Options

| API | Auth | Rate Limit | Cloud OK? | Best For |
|-----|------|------------|-----------|----------|
| **nba_api** (stats.nba.com) | None | ~600ms between calls | ❌ NO | Local dev, comprehensive stats |
| **nba_api live** (cdn.nba.com) | None | Generous | ✅ Maybe | Today's games, live scores |
| **balldontlie** | API Key | 60/min (free) | ✅ YES | Production apps, clean API |
| **cdn.nba.com/static** | None | None | ✅ YES | Schedule data only |

### Paid Options

| API | Starting Price | Notes |
|-----|----------------|-------|
| SportsDataIO | ~$20/mo | Official data partner |
| Sportradar | Enterprise | Used by major sportsbooks |
| API-Sports (RapidAPI) | ~$10/mo | Good middle ground |

**Recommendation for NBA Oracle:** Start with `nba_api` for development. For production, either:
- Pre-fetch historical data locally and deploy static ML models
- Use balldontlie.io for live game data (free tier is enough)

---

## The nba_api Package

### Overview

The `nba_api` package by Swar Patel is the **most comprehensive** free NBA data library. It wraps the undocumented APIs used by nba.com and stats.nba.com.

```bash
pip install nba_api
```

**Requirements:** Python 3.10+, requests, numpy
**Optional:** pandas (for DataFrames)

### Package Structure

```
nba_api/
├── stats/              # Historical stats from stats.nba.com
│   ├── endpoints/      # 70+ API endpoints
│   │   ├── scoreboardv2.py
│   │   ├── leaguegamefinder.py
│   │   ├── teamgamelog.py
│   │   ├── playercareerstats.py
│   │   └── ... (many more)
│   └── static/         # Cached player/team data
│       ├── players.py
│       └── teams.py
└── live/               # Live data from cdn.nba.com
    └── nba/
        └── endpoints/
            ├── scoreboard.py    # Today's games
            ├── boxscore.py      # Live box scores
            └── playbyplay.py    # Play-by-play
```

### Two Data Sources

| Source | Base URL | Use Case |
|--------|----------|----------|
| **stats** | stats.nba.com | Historical data, detailed stats |
| **live** | cdn.nba.com | Today's games, live scores |

The **live** endpoints are newer and may have better cloud compatibility.

### Static Data (No API Call Needed)

```python
from nba_api.stats.static import teams, players

# Get all NBA teams
all_teams = teams.get_teams()
# Returns: [{'id': 1610612737, 'full_name': 'Atlanta Hawks', 'abbreviation': 'ATL', ...}, ...]

# Find a specific team
lakers = teams.find_teams_by_nickname('lakers')[0]
# {'id': 1610612747, 'full_name': 'Los Angeles Lakers', ...}

# Get all players (current and historical)
all_players = players.get_players()

# Find specific player
lebron = players.find_players_by_full_name('LeBron James')[0]
# {'id': 2544, 'full_name': 'LeBron James', ...}
```

### Key Team IDs

| Team | ID | Abbreviation |
|------|-------|--------------|
| Los Angeles Lakers | 1610612747 | LAL |
| Boston Celtics | 1610612738 | BOS |
| Golden State Warriors | 1610612744 | GSW |
| Denver Nuggets | 1610612743 | DEN |
| Phoenix Suns | 1610612756 | PHX |
| Miami Heat | 1610612748 | MIA |

**Full list:** `nba_api.stats.static.teams.get_teams()`

---

## Alternative APIs

### balldontlie.io

**Best alternative for production.** Clean REST API with official SDKs.

```bash
pip install balldontlie
```

```python
from balldontlie import BalldontlieAPI
from datetime import date

api = BalldontlieAPI(api_key="your-api-key")

# Today's games
today = date.today().isoformat()
games = api.nba.games.list(dates=[today])

for game in games['data']:
    home = game['home_team']['abbreviation']
    away = game['visitor_team']['abbreviation']
    status = game['status']
    print(f"{away} @ {home}: {status}")
```

**Pricing:**
- Free: Basic endpoints, 60 requests/minute
- Pro ($9.99/mo): Advanced stats, betting odds
- All-Access ($159.99/mo): Everything

**Key Endpoints:**
- `GET /nba/v1/games` - Games by date
- `GET /nba/v1/stats` - Player box scores
- `GET /nba/v1/standings` - Team standings
- `GET /nba/v1/box_scores/live` - Live box scores

### Direct CDN Access

For just the schedule, you can hit the CDN directly:

```python
import requests

# Full season schedule
url = "https://cdn.nba.com/static/json/staticData/scheduleLeagueV2.json"
schedule = requests.get(url).json()

# Today's scoreboard
url = "https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json"
today = requests.get(url).json()
```

---

## Cloud Hosting Warning

### ⚠️ CRITICAL: stats.nba.com Blocks Cloud IPs

The NBA actively blocks requests from:
- AWS (EC2, Lambda, etc.)
- Google Cloud
- Heroku
- DigitalOcean
- Azure
- Most other cloud providers

**Symptoms:**
- Requests hang indefinitely
- `TimeoutError` after 30 seconds
- `ConnectionError: Connection aborted`

**Why?** The NBA treats cloud IPs as bots to prevent:
- DDOS attacks
- Scraping at scale
- Commercial data extraction

### Workarounds

**Option 1: Local Pre-fetch (Recommended for NBA Oracle)**
```python
# Run locally, save to JSON/CSV
# Deploy the cached data with your app

# Local machine:
games = leaguegamefinder.LeagueGameFinder(season_nullable='2024-25').get_data_frames()[0]
games.to_csv('historical_games.csv', index=False)

# Then include CSV in your Docker image
```

**Option 2: Use balldontlie (cloud-friendly)**
```python
# Works fine on AWS/Heroku
api = BalldontlieAPI(api_key="...")
```

**Option 3: Proxy Service**
```python
# Use residential proxies (paid services like webshare.io)
from nba_api.stats.endpoints import playercareerstats

career = playercareerstats.PlayerCareerStats(
    player_id='203999',
    proxy='http://user:pass@proxy.webshare.io:80'
)
```

**Option 4: Hybrid Architecture**
- Backend on cheap VPS (not blocked)
- Frontend on Vercel (free)
- Use VPS as proxy to fetch NBA data

---

## Key Endpoints for Your Project

### For Today's Games (Display)

| Endpoint | Package | Returns |
|----------|---------|---------|
| `ScoreBoard` | live | Today's games + live scores |
| `ScoreboardV2` | stats | Today's games + standings |

### For ML Training (Historical Data)

| Endpoint | Returns | Use Case |
|----------|---------|----------|
| `LeagueGameFinder` | All games for team/player | Get historical matchups |
| `LeagueGameLog` | Game results by season | Season-level analysis |
| `TeamGameLog` | Single team's game log | Team performance trends |
| `TeamEstimatedMetrics` | Advanced team stats | Feature engineering |

### For Feature Engineering

| Endpoint | Data | ML Features |
|----------|------|-------------|
| `TeamDashboardByGeneralSplits` | Home/away splits | Home court advantage |
| `LeagueStandings` | Current standings | Win %, conference rank |
| `TeamInfoCommon` | Team metadata | Conference, division |

---

## Getting Today's Games

### Method 1: nba_api Live (Recommended)

```python
from nba_api.live.nba.endpoints import scoreboard

# Get today's scoreboard
games = scoreboard.ScoreBoard()

# As dictionary
data = games.get_dict()

# Structure:
# {
#   'meta': {...},
#   'scoreboard': {
#     'gameDate': '2026-01-07',
#     'games': [
#       {
#         'gameId': '0022400123',
#         'gameStatus': 1,  # 1=scheduled, 2=in progress, 3=final
#         'gameStatusText': '7:30 pm ET',
#         'homeTeam': {
#           'teamId': 1610612747,
#           'teamName': 'Lakers',
#           'teamCity': 'Los Angeles',
#           'teamTricode': 'LAL',
#           'score': 0
#         },
#         'awayTeam': {...}
#       }
#     ]
#   }
# }
```

### Method 2: nba_api Stats (More Details)

```python
from nba_api.stats.endpoints import scoreboardv2
from datetime import datetime

# Get today's date in required format
today = datetime.now().strftime('%Y-%m-%d')

# Fetch scoreboard
sb = scoreboardv2.ScoreboardV2(game_date=today)

# Get game headers
game_header = sb.game_header.get_data_frame()
# Columns: GAME_DATE_EST, GAME_ID, GAME_STATUS_ID, HOME_TEAM_ID, VISITOR_TEAM_ID, ...

# Get line scores (current scores by quarter)
line_score = sb.line_score.get_data_frame()
# Columns: TEAM_ID, TEAM_ABBREVIATION, PTS_QTR1, PTS_QTR2, ..., PTS
```

### Method 3: Direct CDN (Most Reliable for Cloud)

```python
import requests
import json

def get_todays_games():
    url = "https://cdn.nba.com/static/json/liveData/scoreboard/todaysScoreboard_00.json"

    headers = {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json',
        'Referer': 'https://www.nba.com/'
    }

    response = requests.get(url, headers=headers, timeout=10)
    data = response.json()

    games = []
    for game in data['scoreboard']['games']:
        games.append({
            'game_id': game['gameId'],
            'status': game['gameStatusText'],
            'home_team': game['homeTeam']['teamTricode'],
            'away_team': game['awayTeam']['teamTricode'],
            'home_score': game['homeTeam']['score'],
            'away_score': game['awayTeam']['score'],
            'game_time': game.get('gameTimeUTC', '')
        })

    return games
```

---

## Historical Data for ML Training

### Getting All Games for a Season

```python
from nba_api.stats.endpoints import leaguegamelog
import time

def get_season_games(season='2024-25', season_type='Regular Season'):
    """
    Get all games for a season.

    Args:
        season: Format 'YYYY-YY' (e.g., '2024-25')
        season_type: 'Regular Season', 'Playoffs', 'Pre Season'
    """
    gamelog = leaguegamelog.LeagueGameLog(
        season=season,
        season_type_all_star=season_type,
        player_or_team_abbreviation='T'  # T for Team
    )

    df = gamelog.get_data_frames()[0]
    return df

# Columns returned:
# SEASON_ID, TEAM_ID, TEAM_ABBREVIATION, TEAM_NAME, GAME_ID, GAME_DATE,
# MATCHUP, WL, MIN, PTS, FGM, FGA, FG_PCT, FG3M, FG3A, FG3_PCT,
# FTM, FTA, FT_PCT, OREB, DREB, REB, AST, STL, BLK, TOV, PF, PLUS_MINUS
```

### Getting Multiple Seasons (Rate-Limit Safe)

```python
import pandas as pd
import time

def get_multi_season_data(start_year=2020, end_year=2024):
    """Get multiple seasons of game data."""

    all_games = []

    for year in range(start_year, end_year + 1):
        season = f"{year}-{str(year+1)[-2:]}"  # e.g., "2020-21"
        print(f"Fetching {season}...")

        try:
            df = get_season_games(season)
            df['SEASON'] = season
            all_games.append(df)

            # IMPORTANT: Rate limiting
            time.sleep(0.6)  # 600ms between requests

        except Exception as e:
            print(f"Error fetching {season}: {e}")
            continue

    return pd.concat(all_games, ignore_index=True)
```

### Getting Team-Level Game Logs

```python
from nba_api.stats.endpoints import teamgamelog

def get_team_games(team_id, season='2024-25'):
    """Get all games for a specific team."""

    gamelog = teamgamelog.TeamGameLog(
        team_id=team_id,
        season=season,
        season_type_all_star='Regular Season'
    )

    return gamelog.get_data_frames()[0]

# Example: Get Lakers games
lakers_games = get_team_games(1610612747)
```

### Using LeagueGameFinder (Most Flexible)

```python
from nba_api.stats.endpoints import leaguegamefinder

def find_games(team_id=None, season=None, date_from=None, date_to=None):
    """
    Flexible game finder with many filter options.
    """

    finder = leaguegamefinder.LeagueGameFinder(
        team_id_nullable=team_id,
        season_nullable=season,
        date_from_nullable=date_from,
        date_to_nullable=date_to,
        league_id_nullable='00',  # NBA
        player_or_team_abbreviation='T'
    )

    return finder.get_data_frames()[0]

# Get all games between two dates
recent_games = find_games(date_from='01/01/2026', date_to='01/07/2026')

# Get all Lakers vs Celtics games in 2024-25
lakers_games = find_games(team_id=1610612747, season='2024-25')
```

---

## ML Prediction Insights

### Typical Accuracy Ranges

Based on research from existing NBA prediction projects:

| Approach | Accuracy | Notes |
|----------|----------|-------|
| Always pick home team | ~59% | Baseline (home court advantage) |
| Simple win rate model | ~60-62% | Just using season W/L % |
| Basic ML (Random Forest) | ~63-66% | Standard box score features |
| Advanced ML (XGBoost/LGBM) | ~67-70% | Rolling averages, advanced stats |
| Deep Learning | ~68-72% | Diminishing returns past this |
| **Vegas lines** | ~73-75% | The benchmark to beat |

**Key Insight:** Getting above 65% accuracy is achievable. Beating Vegas (~75%) is extremely difficult.

### Important Features (from research)

**High Impact:**
- Home court advantage (~59% base win rate)
- Recent performance (last 5-10 games)
- Head-to-head history
- Rest days (back-to-back games matter)
- Point differential (better than W/L %)

**Medium Impact:**
- Effective FG% differential
- Turnover differential
- Rebounding differential
- Three-point shooting trends

**Lower Impact (surprisingly):**
- Overall season record
- Individual player stats (unless injured)

### Feature Engineering Tips

```python
def create_ml_features(games_df):
    """
    Create features for ML training.
    Note: Only use data available BEFORE the game!
    """

    features = games_df.copy()

    # Rolling averages (last N games)
    for col in ['PTS', 'FG_PCT', 'REB', 'AST', 'TOV']:
        features[f'{col}_LAST5'] = features.groupby('TEAM_ID')[col].transform(
            lambda x: x.shift(1).rolling(5).mean()
        )

    # Win streak
    features['WIN'] = (features['WL'] == 'W').astype(int)
    features['WIN_STREAK'] = features.groupby('TEAM_ID')['WIN'].transform(
        lambda x: x.shift(1).rolling(5).sum()
    )

    # Rest days (requires game dates)
    features['GAME_DATE'] = pd.to_datetime(features['GAME_DATE'])
    features['REST_DAYS'] = features.groupby('TEAM_ID')['GAME_DATE'].diff().dt.days

    return features
```

### Common Mistakes to Avoid

1. **Data Leakage:** Using game outcome data as features (the thing you're predicting!)
2. **Future Data:** Features must only use data available BEFORE the game
3. **Imbalanced Splits:** Don't train on 2024 and test on 2020
4. **Ignoring Home/Away:** Always create features relative to home/away
5. **Over-engineering:** Simple features often beat complex ones

---

## Code Examples

### Complete: Fetch Today's Games for FastAPI

```python
# backend/app/services/nba_service.py

from nba_api.live.nba.endpoints import scoreboard
from nba_api.stats.static import teams
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class NBAService:
    def __init__(self):
        self._teams_cache = {t['id']: t for t in teams.get_teams()}

    def get_team_info(self, team_id: int) -> dict:
        return self._teams_cache.get(team_id, {})

    async def get_todays_games(self) -> list[dict]:
        """Fetch today's NBA games."""
        try:
            sb = scoreboard.ScoreBoard()
            data = sb.get_dict()

            games = []
            for game in data['scoreboard']['games']:
                home = game['homeTeam']
                away = game['awayTeam']

                games.append({
                    'id': game['gameId'],
                    'game_time': game.get('gameTimeUTC', ''),
                    'status': game['gameStatusText'],
                    'status_code': game['gameStatus'],
                    'home_team': {
                        'id': home['teamId'],
                        'name': f"{home['teamCity']} {home['teamName']}",
                        'abbreviation': home['teamTricode'],
                        'score': home['score']
                    },
                    'away_team': {
                        'id': away['teamId'],
                        'name': f"{away['teamCity']} {away['teamName']}",
                        'abbreviation': away['teamTricode'],
                        'score': away['score']
                    }
                })

            return games

        except Exception as e:
            logger.error(f"Failed to fetch games: {e}")
            return []

# Usage in FastAPI router
from fastapi import APIRouter, HTTPException
from app.services.nba_service import NBAService

router = APIRouter()
nba_service = NBAService()

@router.get("/today")
async def get_todays_games():
    games = await nba_service.get_todays_games()
    if not games:
        # Return empty list, not error (might just be no games today)
        return []
    return games
```

### Complete: Historical Data Collection Script

```python
# scripts/collect_historical_data.py

from nba_api.stats.endpoints import leaguegamelog
from nba_api.stats.static import teams
import pandas as pd
import time
import os

def collect_seasons(start_year: int, end_year: int, output_dir: str = 'data'):
    """
    Collect historical NBA game data.
    Run this locally, then include output in your Docker image.
    """

    os.makedirs(output_dir, exist_ok=True)
    all_games = []

    for year in range(start_year, end_year + 1):
        season = f"{year}-{str(year+1)[-2:]}"
        print(f"📊 Fetching {season}...")

        try:
            # Regular season
            gamelog = leaguegamelog.LeagueGameLog(
                season=season,
                season_type_all_star='Regular Season',
                player_or_team_abbreviation='T'
            )
            df = gamelog.get_data_frames()[0]
            df['SEASON'] = season
            df['SEASON_TYPE'] = 'Regular'
            all_games.append(df)

            time.sleep(0.6)  # Rate limit

            # Playoffs
            gamelog_po = leaguegamelog.LeagueGameLog(
                season=season,
                season_type_all_star='Playoffs',
                player_or_team_abbreviation='T'
            )
            df_po = gamelog_po.get_data_frames()[0]
            if len(df_po) > 0:
                df_po['SEASON'] = season
                df_po['SEASON_TYPE'] = 'Playoffs'
                all_games.append(df_po)

            time.sleep(0.6)
            print(f"   ✅ {len(df)} regular season + {len(df_po)} playoff games")

        except Exception as e:
            print(f"   ❌ Error: {e}")
            continue

    # Combine and save
    full_df = pd.concat(all_games, ignore_index=True)

    output_path = os.path.join(output_dir, 'nba_games_historical.csv')
    full_df.to_csv(output_path, index=False)

    print(f"\n✅ Saved {len(full_df)} games to {output_path}")
    return full_df

if __name__ == '__main__':
    # Collect last 5 seasons
    collect_seasons(2020, 2024)
```

---

## Rate Limiting & Best Practices

### Rate Limits

| Source | Limit | Recommendation |
|--------|-------|----------------|
| stats.nba.com | ~100/min | 600ms between calls |
| cdn.nba.com (live) | Unknown (generous) | 200ms between calls |
| balldontlie (free) | 60/min | 1 second between calls |

### Best Practices

```python
import time
from functools import wraps

# Rate limiter decorator
def rate_limited(min_interval=0.6):
    """Decorator to rate-limit API calls."""
    last_called = [0]

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            elapsed = time.time() - last_called[0]
            if elapsed < min_interval:
                time.sleep(min_interval - elapsed)
            result = func(*args, **kwargs)
            last_called[0] = time.time()
            return result
        return wrapper
    return decorator

@rate_limited(0.6)
def get_team_stats(team_id, season):
    from nba_api.stats.endpoints import teamgamelog
    return teamgamelog.TeamGameLog(team_id=team_id, season=season)
```

### Headers (If Needed)

```python
custom_headers = {
    'Host': 'stats.nba.com',
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.nba.com/',
    'x-nba-stats-origin': 'stats',
    'x-nba-stats-token': 'true',
    'Connection': 'keep-alive'
}

# Pass to any endpoint
from nba_api.stats.endpoints import commonplayerinfo
player = commonplayerinfo.CommonPlayerInfo(
    player_id=2544,
    headers=custom_headers,
    timeout=30
)
```

---

## Useful Resources

### Documentation

- [nba_api GitHub](https://github.com/swar/nba_api) - Main package repo
- [nba_api Docs](https://nba-apidocumentation.knowledgeowl.com/help) - Endpoint documentation
- [balldontlie Docs](https://docs.balldontlie.io/) - Alternative API docs

### Example Projects

| Project | Accuracy | Approach |
|---------|----------|----------|
| [NBA-Machine-Learning-Sports-Betting](https://github.com/kyleskom/NBA-Machine-Learning-Sports-Betting) | ~69% | XGBoost + Neural Network |
| [nba-prediction](https://github.com/cmunch1/nba-prediction) | ~67% | LightGBM with calibration |
| [NBA-Prediction-Modeling](https://github.com/luke-lite/NBA-Prediction-Modeling) | ~65% | Random Forest, PCA |

### Dataset Sources

| Source | Coverage | Format |
|--------|----------|--------|
| [shufinskiy/nba_data](https://github.com/shufinskiy/nba_data) | 1996-present | CSV (play-by-play) |
| [NBA-Data-2010-2024](https://github.com/NocturneBear/NBA-Data-2010-2024) | 2010-2024 | CSV |
| [Kaggle NBA Dataset](https://www.kaggle.com/datasets/wyattowalsh/basketball) | Comprehensive | SQLite |

### Community

- [nba_api Slack](https://nba-api-slack.herokuapp.com/) - Get help
- [StackOverflow tag: nba-api](https://stackoverflow.com/questions/tagged/nba-api) - Q&A

---

## Quick Reference Card

```
# Today's Games
from nba_api.live.nba.endpoints import scoreboard
games = scoreboard.ScoreBoard().get_dict()

# Historical Games
from nba_api.stats.endpoints import leaguegamelog
games = leaguegamelog.LeagueGameLog(season='2024-25').get_data_frames()[0]

# Find Games
from nba_api.stats.endpoints import leaguegamefinder
games = leaguegamefinder.LeagueGameFinder(team_id_nullable=1610612747).get_data_frames()[0]

# Team Info
from nba_api.stats.static import teams
all_teams = teams.get_teams()

# Player Info
from nba_api.stats.static import players
all_players = players.get_players()
```

---

**Document Version:** 1.0
**Last Updated:** January 2026
**For Project:** NBA Oracle (nbaoracle.com)
