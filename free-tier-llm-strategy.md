# Free Tier LLM Strategy & API Call Capacity Analysis

## Executive Summary

This document analyzes free tier LLM providers in 2026, calculates maximum API call capacity, and proposes a fallback strategy to maximize free usage across multiple providers.

## 🎯 Core Strategy

**Intelligent Fallback Chain**: Use providers in sequence based on quota exhaustion, with automatic failover when rate limits or daily quotas are hit.

---

## 📊 Provider Analysis & Capacity Calculation

### Tier 1: Most Generous Free Tiers (No Credit Card Required)

#### 1. **Google Gemini** 🥇 Best Overall
**Models & Daily Limits:**
- **Gemini 2.0 Flash**: 250 requests/day, 10 RPM, 250K TPM
- **Gemini 2.5 Flash**: 500 requests/day, 15 RPM
- **Gemini 2.5 Pro**: 25 requests/day, 2 RPM
- **Gemini 1.5 Flash**: 1,500 requests/day, 15 RPM (if still available)

**Daily Capacity**: **2,275 requests/day** (all models combined)
**Monthly Capacity**: **~68,250 requests/month**

**Pros:**
- Most generous free tier in industry
- Multiple model tiers
- Commercial use allowed (except EU/EEA/UK/Switzerland)
- No credit card required

**Cons:**
- Daily quotas reset at midnight PT
- Per-project limits (not per API key)
- Recent quota reductions (Dec 2025)

---

#### 2. **Groq** 🥈 Fast Inference
**Models & Limits:**
- **Llama 3.3 70B**: 1,000 requests/day, 30 RPM, 12K TPM
- **Llama 3.1 8B**: 14,400 requests/day, 30 RPM, 6K TPM
- **Mixtral 8x7B**: Similar limits (~30 RPM)
- **Gemma 2 9B**: Similar limits

**Daily Capacity**: **~15,400 requests/day**
**Monthly Capacity**: **~462,000 requests/month**

**Pros:**
- Extremely fast inference (~500 tokens/sec)
- Multiple open-source models
- Organization-level limits
- No credit card required

**Cons:**
- Lower TPM limits may constrain large responses
- Rate limits apply per organization

---

#### 3. **OpenRouter** 🎁 Multi-Model Access
**Free Models:**
- 25+ models with `:free` suffix
- Access to DeepSeek R1, Llama, Mistral, etc.

**Limits:**
- **20 requests/minute**
- **200 requests/day** for free models

**Daily Capacity**: **200 requests/day**
**Monthly Capacity**: **~6,000 requests/month**

**Pros:**
- Access to 290+ models through unified API
- No commitment, pay-as-you-go for paid models
- Good for testing different models

**Cons:**
- Limited free tier
- Need credits for non-free models

---

#### 4. **Cloudflare Workers AI** ☁️ Edge Inference
**Free Allocation:**
- 10,000 Neurons/day (resets at 00:00 UTC)
- Pricing: ~2,457-26,668 neurons per 1M tokens depending on model

**Approximate Capacity:**
- **Llama 3.2 1B**: ~4,000 requests/day (assuming 250 tokens/request)
- **Llama 3.1 70B**: ~375 requests/day (assuming 250 tokens/request)

**Daily Capacity**: **375-4,000 requests/day** (model dependent)
**Monthly Capacity**: **~11,250-120,000 requests/month**

**Pros:**
- Edge deployment
- Multiple open-source models
- Low latency globally

**Cons:**
- Neuron-based pricing can be complex
- Varies significantly by model size

---

#### 5. **Mistral AI** 🇫🇷
**Free Tier:**
- 1 billion tokens/month
- Models: Mistral Small, Codestral

**Approximate Capacity:**
- Assuming 500 tokens per request: **~2,000,000 requests/month**
- Realistically: **~66,666 requests/day**

**Pros:**
- Extremely generous token allocation
- No credit card required
- Good for code generation

**Cons:**
- Limited model selection in free tier
- Less documentation than major providers

---

#### 6. **DeepSeek** 💎 Highly Competitive
**Free Tier:**
- 5 million free tokens
- No hard rate limits
- Extremely cheap beyond free tier

**Approximate Capacity:**
- Assuming 500 tokens per request: **~10,000 requests** (one-time)
- After free tokens: Very cheap ($0.14/M tokens input)

**Pros:**
- Very generous initial allocation
- Cheapest pricing after free tier
- Good reasoning capabilities (R1 model)

**Cons:**
- Free tokens are one-time, not monthly
- May require credit card

---

### Tier 2: Limited Free Credits (Credit Card Required)

#### 7. **OpenAI**
- New accounts get limited credits (varies by region)
- Minimum $5 top-up after credits expire
- Not sustainable for free-tier strategy

#### 8. **Anthropic (Claude)**
- Limited free credits for new accounts
- Minimum $5 top-up required
- Not sustainable for free-tier strategy

---

## 💰 Total Free Capacity Summary

### Daily Maximum (Conservative Estimates)
| Provider | Daily Requests | Notes |
|----------|----------------|-------|
| Gemini | 2,275 | Multiple models |
| Groq | 15,400 | Fast inference |
| OpenRouter | 200 | Free models only |
| Cloudflare | 1,000 | Mid-size models |
| Mistral | 66,666 | Token-based |
| **TOTAL** | **~85,541** | **Per day across all providers** |

### Monthly Maximum
- **~2,566,230 requests/month** (30 days)
- **~30 million+ tokens/month** (assuming 350 tokens avg per request)

---

## 🏗️ Implementation Strategy

### Phase 1: Intelligent Fallback System

```python
PROVIDER_CONFIGS = [
    # Tier 1: Gemini (highest quality for free)
    {"provider": "gemini", "model": "gemini-2.5-flash", "daily_quota": 500, "rpm": 15},
    {"provider": "gemini", "model": "gemini-2.0-flash", "daily_quota": 250, "rpm": 10},
    {"provider": "gemini", "model": "gemini-2.5-pro", "daily_quota": 25, "rpm": 2},
    
    # Tier 2: Groq (fast inference, high volume)
    {"provider": "groq", "model": "llama-3.3-70b-versatile", "daily_quota": 1000, "rpm": 30},
    {"provider": "groq", "model": "llama-3.1-8b-instant", "daily_quota": 14400, "rpm": 30},
    
    # Tier 3: Mistral (massive token allowance)
    {"provider": "mistral", "model": "mistral-small-latest", "monthly_tokens": 1000000000},
    
    # Tier 4: OpenRouter (fallback diversity)
    {"provider": "openrouter", "model": "free/llama-3-8b", "daily_quota": 200, "rpm": 20},
    
    # Tier 5: Cloudflare (edge inference backup)
    {"provider": "cloudflare", "model": "llama-3.1-70b", "daily_neurons": 10000},
    
    # Tier 6: DeepSeek (one-time large allocation)
    {"provider": "deepseek", "model": "deepseek-chat", "total_tokens": 5000000},
]
```

### Phase 2: Quota Tracking System

**Features:**
1. **Daily Quota Counter**: Track requests per provider per day
2. **Rate Limit Handling**: Respect RPM limits with exponential backoff
3. **Automatic Reset**: Reset counters at midnight for daily quotas
4. **Persistent Storage**: Store quota usage in database/cache

**Database Schema:**
```sql
CREATE TABLE llm_quota_usage (
    id SERIAL PRIMARY KEY,
    provider VARCHAR(50),
    model VARCHAR(100),
    date DATE,
    requests_used INT DEFAULT 0,
    tokens_used BIGINT DEFAULT 0,
    last_request_at TIMESTAMP,
    quota_exhausted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_quota_provider_date ON llm_quota_usage(provider, date);
```

### Phase 3: Smart Fallback Logic

**Error Handling:**
- **429 (Rate Limit)**: Move to next provider immediately
- **403 (Quota Exceeded)**: Mark provider as exhausted for the day
- **5xx (Server Error)**: Retry with exponential backoff, then fallback
- **400 (Bad Request)**: Don't fallback (fix request instead)

**Cost Optimization:**
- Prefer free models over paid when quality difference is minimal
- Use smaller models (Llama 3.1 8B) for simple tasks
- Reserve larger models (Gemini Pro, Llama 70B) for complex reasoning

---

## 🔧 Code Implementation

### Enhanced Quota Tracking

```python
import time
from datetime import datetime, timedelta
from typing import Optional

class QuotaManager:
    """Manage provider quotas and rate limits."""
    
    def __init__(self, db_connection):
        self.db = db_connection
        self.in_memory_cache = {}  # For rate limiting
    
    def can_use_provider(self, provider: str, model: str) -> bool:
        """Check if provider has available quota."""
        today = datetime.now().date()
        
        # Check database for daily quota
        usage = self._get_usage(provider, model, today)
        config = self._get_config(provider, model)
        
        if not config:
            return False
        
        # Check daily quota
        if "daily_quota" in config:
            if usage["requests_used"] >= config["daily_quota"]:
                return False
        
        # Check rate limit (RPM)
        if "rpm" in config:
            if not self._check_rate_limit(provider, model, config["rpm"]):
                return False
        
        return True
    
    def _check_rate_limit(self, provider: str, model: str, rpm: int) -> bool:
        """Check if within rate limit."""
        key = f"{provider}:{model}"
        now = time.time()
        
        if key not in self.in_memory_cache:
            self.in_memory_cache[key] = []
        
        # Remove requests older than 1 minute
        self.in_memory_cache[key] = [
            ts for ts in self.in_memory_cache[key] 
            if now - ts < 60
        ]
        
        # Check if under limit
        return len(self.in_memory_cache[key]) < rpm
    
    def record_request(self, provider: str, model: str, tokens: int):
        """Record a successful request."""
        key = f"{provider}:{model}"
        now = time.time()
        
        # Update in-memory cache
        if key not in self.in_memory_cache:
            self.in_memory_cache[key] = []
        self.in_memory_cache[key].append(now)
        
        # Update database
        self._increment_usage(provider, model, datetime.now().date(), 1, tokens)
```

### Enhanced Failover Logic

```python
class SmartFailoverChatLLM(FailoverChatLLM):
    """Enhanced failover with quota awareness."""
    
    def __init__(self, candidates, quota_manager):
        super().__init__(candidates, enable_cooldown=False)
        self.quota_manager = quota_manager
    
    def invoke(self, *args, **kwargs):
        """Invoke with quota awareness."""
        last_exc = None
        
        for index, (provider, model, llm) in enumerate(self._candidates):
            # Check quota before attempting
            if not self.quota_manager.can_use_provider(provider, model):
                logger.info(f"Skipping {provider}/{model} - quota exhausted")
                continue
            
            logger.info(f"Trying {provider}/{model}")
            
            try:
                response = llm.invoke(*args, **kwargs)
                
                # Record successful request
                tokens = self._estimate_tokens(response)
                self.quota_manager.record_request(provider, model, tokens)
                
                self._active_index = index
                return response
                
            except Exception as exc:
                # Handle specific errors
                if self._is_quota_error(exc):
                    logger.warning(f"{provider}/{model} quota exceeded")
                    # Mark as exhausted in quota manager
                    continue
                
                if self._is_rate_limit_error(exc):
                    logger.warning(f"{provider}/{model} rate limited")
                    continue
                
                if not _is_fallback_error(exc):
                    raise
                
                last_exc = exc
        
        if last_exc:
            raise last_exc
        raise RuntimeError("All providers exhausted or unavailable")
```

---

## 🔄 OpenClaw Integration

OpenClaw already supports multiple providers through its unified configuration. Here's how to integrate the free-tier strategy:

### Current OpenClaw Setup
Your `openclaw.json` shows:
- **Ollama** (local, unlimited)
- **Groq** (already configured)
- **OpenRouter** (already configured)

### Enhanced OpenClaw Configuration

```json
{
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://127.0.0.1:11434/v1",
        "apiKey": "ollama-local",
        "cost": {"input": 0, "output": 0}
      },
      "gemini": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
        "apiKey": "YOUR_GEMINI_KEY",
        "models": [
          {"id": "gemini-2.5-flash", "dailyQuota": 500, "rpm": 15},
          {"id": "gemini-2.0-flash", "dailyQuota": 250, "rpm": 10}
        ]
      },
      "groq": {
        "baseUrl": "https://api.groq.com/openai/v1",
        "apiKey": "YOUR_GROQ_KEY",
        "models": [
          {"id": "llama-3.3-70b-versatile", "dailyQuota": 1000, "rpm": 30},
          {"id": "llama-3.1-8b-instant", "dailyQuota": 14400, "rpm": 30}
        ]
      },
      "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "apiKey": "YOUR_OPENROUTER_KEY",
        "models": [
          {"id": "free/llama-3-8b", "dailyQuota": 200, "rpm": 20}
        ]
      },
      "mistral": {
        "baseUrl": "https://api.mistral.ai/v1",
        "apiKey": "YOUR_MISTRAL_KEY",
        "models": [
          {"id": "mistral-small-latest", "monthlyTokens": 1000000000}
        ]
      },
      "cloudflare": {
        "baseUrl": "https://api.cloudflare.com/client/v4/accounts/YOUR_ACCOUNT/ai/run",
        "apiKey": "YOUR_CF_KEY",
        "models": [
          {"id": "@cf/meta/llama-3.1-70b-instruct", "dailyNeurons": 10000}
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "ollama/qwen3:8b",
        "fallback": [
          "gemini/gemini-2.5-flash",
          "groq/llama-3.3-70b-versatile",
          "mistral/mistral-small-latest",
          "openrouter/free/llama-3-8b"
        ]
      }
    }
  }
}
```

### OpenClaw Usage Strategy

1. **Local First**: Use Ollama for most tasks (free, fast, private)
2. **Cloud Fallback**: When local model isn't sufficient, use cloud providers
3. **Priority Order**:
   - Ollama (local, unlimited)
   - Gemini (highest quality free tier)
   - Groq (fast inference, high volume)
   - Mistral (massive token allowance)
   - OpenRouter (diversity)
   - Cloudflare (edge backup)

---

## 📈 Usage Recommendations

### Rajniti Project
**Expected Usage**: Political data analysis, user queries, MP information

**Strategy:**
1. Start with Gemini 2.5 Flash (500/day)
2. Overflow to Groq Llama 3.3 70B (1000/day)
3. High-volume tasks → Groq Llama 3.1 8B (14,400/day)
4. Extended usage → Mistral (1B tokens/month)

**Expected Capacity**: **~85,000 requests/day** = sufficient for **100-500 concurrent users**

### OpenClaw Project
**Expected Usage**: Personal AI assistant, WhatsApp integration

**Strategy:**
1. Primary: Ollama (local, unlimited)
2. Complex tasks: Gemini 2.5 Flash
3. Fallback: Groq/OpenRouter

**Expected Capacity**: Unlimited local + 85,000 cloud requests/day

---

## 🚨 Monitoring & Alerts

### Key Metrics to Track
1. **Daily quota usage** per provider
2. **Request success/failure rates**
3. **Average tokens per request**
4. **Provider distribution** (which providers are used most)
5. **Cost projection** (if quotas are exceeded)

### Alert Thresholds
- **Warning**: 80% of daily quota used
- **Critical**: 95% of daily quota used
- **Info**: Automatic fallback triggered

### Dashboard Recommendations
```python
# Example metrics
{
    "gemini_2.5_flash": {
        "quota": 500,
        "used": 387,
        "remaining": 113,
        "percentage": 77.4,
        "reset_in": "5h 23m"
    },
    "groq_llama_3.3_70b": {
        "quota": 1000,
        "used": 42,
        "remaining": 958,
        "percentage": 4.2,
        "reset_in": "5h 23m"
    },
    "total_requests_today": 429,
    "total_cost_saved": 0.00  # All free
}
```

---

## 🎓 Best Practices

### 1. Model Selection by Task
- **Simple queries**: Llama 3.1 8B, Mistral Small
- **Complex reasoning**: Gemini 2.5 Pro, Llama 3.3 70B
- **Code generation**: Mistral Codestral, DeepSeek
- **Fast responses**: Groq models (any)

### 2. Token Optimization
- Use smaller context windows when possible
- Implement response caching for repeated queries
- Truncate conversation history intelligently

### 3. Fallback Strategy
- Don't retry on quota errors with same provider
- Move to next provider immediately on 429
- Log all fallback events for analysis

### 4. Geographic Considerations
- Gemini quotas may vary by region
- Reset times vary (Gemini: midnight PT, Cloudflare: midnight UTC)
- Consider timezone when planning high-volume tasks

---

## 🔮 Future Enhancements

### 1. Multi-Region Support
- Use different API keys for different regions (if allowed)
- Distribute load geographically

### 2. Intelligent Model Selection
- Use smaller models for confidence-verified tasks
- Route based on task complexity (classifier)

### 3. Hybrid Local + Cloud
- Run sentiment analysis locally
- Use cloud for complex reasoning

### 4. Cost Optimization
- Track actual costs vs free tier
- Automatically switch to paid tier if ROI is positive

---

## 📊 Comparison Table

| Provider | Daily Requests | RPM | Setup | Credit Card | Best For |
|----------|---------------|-----|-------|-------------|----------|
| **Gemini** | 2,275 | 10-15 | Easy | No | General purpose |
| **Groq** | 15,400 | 30 | Easy | No | High volume, speed |
| **Mistral** | 66,666 | Unknown | Medium | No | Long-form content |
| **OpenRouter** | 200 | 20 | Easy | No | Model diversity |
| **Cloudflare** | 1,000 | Unknown | Hard | No | Edge computing |
| **DeepSeek** | ~10,000 (once) | No limit | Easy | Maybe | Initial testing |

---

## ✅ Implementation Checklist

- [ ] Set up API keys for all free providers
- [ ] Implement quota tracking database
- [ ] Create fallback logic with quota awareness
- [ ] Add monitoring dashboard
- [ ] Test failover between providers
- [ ] Configure OpenClaw with multiple providers
- [ ] Document quota reset times
- [ ] Set up alerts for quota thresholds
- [ ] Implement response caching
- [ ] Create usage analytics dashboard

---

## 🎯 Conclusion

By implementing this strategy, you can leverage **~85,000 free API requests per day** across multiple providers, which is sufficient for most small to medium applications. The key is:

1. **Smart fallback**: Automatically move to next provider on quota exhaustion
2. **Quota tracking**: Monitor usage in real-time
3. **Model selection**: Use appropriate model for each task
4. **Cost monitoring**: Track savings and potential costs

**Total Value**: At typical API pricing ($0.50-$3 per 1M tokens), this free tier strategy saves **~$50-300/month** for moderate usage.
