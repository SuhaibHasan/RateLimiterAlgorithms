local token_bucket_script_per_min_rl = [[
    local key = KEYS[1]                     -- Redis key to store token bucket information
    local bucket_capacity = tonumber(ARGV[1])     -- Max tokens allowed in the bucket
    local rate = tonumber(ARGV[2])         -- Rate of token refill per minute
    local tokens_required = tonumber(ARGV[3]) -- Number of tokens required for the action
    
    -- Fetch current bucket data from Redis
    local bucket = redis.call("HMGET", key, "tokens", "last_refill_time")
    local current_tokens = tonumber(bucket[1]) or bucket_capacity
    local redis_time = redis.call("TIME") -- Fetch redis server time
    local current_time = tonumber(redis_time[1])  -- Redis TIME command returns seconds and microseconds
    local last_refill_time = tonumber(bucket[2]) or current_time
    
    -- Calculate tokens need to be added based on the elapsed time
    local elapsed_time = (current_time - last_refill_time)/60
    local tokens_to_add = math.floor(elapsed_time * rate)
    
    -- Refill the bucket with tokens
    current_tokens = math.min(current_tokens + tokens_to_add, bucket_capacity)
    
    -- Check if enough tokens are available to process the action
    if current_tokens >= tokens_required then
        -- Deduct the tokens and return success
        redis.call("HMSET", key, "tokens", current_tokens - tokens_required, "last_refill_time", current_time)
        return 1  -- Success: enough tokens available, request allowed
    else
        -- Not enough tokens available
        return 0  -- Failure: not enough tokens
    end
    ]]

    
local token_bucket_script_per_sec_rl = [[
    local key = KEYS[1]                     -- Redis key to store token bucket information
    local bucket_capacity = tonumber(ARGV[1])     -- Max tokens allowed in the bucket
    local rate = tonumber(ARGV[2])         -- Rate of token refill per minute
    local tokens_required = tonumber(ARGV[3]) -- Number of tokens required for the action
        
    -- Fetch current bucket data from Redis
    local bucket = redis.call("HMGET", key, "tokens", "last_refill_time")
    local current_tokens = tonumber(bucket[1]) or bucket_capacity
    local redis_time = redis.call("TIME") -- Fetch redis server time
    local current_time = tonumber(redis_time[1])*1000 + math.floor(tonumber(redis_time[2])/1000)  -- Redis TIME command returns seconds and microseconds
    local last_refill_time = tonumber(bucket[2]) or current_time
        
    -- Calculate tokens need to be added based on the elapsed time
    local elapsed_time = (current_time - last_refill_time)/1000
    local tokens_to_add = math.floor(elapsed_time * rate)
        
    -- Refill the bucket with tokens
    current_tokens = math.min(current_tokens + tokens_to_add, bucket_capacity)
        
    -- Check if enough tokens are available to process the action
    if current_tokens >= tokens_required then
        -- Deduct the tokens and return success
        redis.call("HMSET", key, "tokens", current_tokens - tokens_required, "last_refill_time", current_time)
        return 1  -- Success: enough tokens available, request allowed
    else
        -- Not enough tokens available
        return 0  -- Failure: not enough tokens
    end
        ]]

 local sliding_window_rl =  [[
    local key = KEYS[1]                     -- Redis key to store sliding window information
    local time_window = tonumber(ARGV[1])     -- Time window in seconds
    local max_request_allowed = tonumber(ARGV[2])   -- Maximum equest allowed in time window  
    local current_time = redis.call('TIME')
    local redis_time_window = tonumber(current_time[1]) - time_window
    redis.call('ZREMRANGEBYSCORE', key, 0, redis_time_window) -- Remove old entries prior to the window
    local request_count = redis.call('ZCARD', key) -- Calculate the count of request

    -- Check if enough request count is available to allow request
    if request_count < max_request_allowed then
        redis.call('ZADD', key, current_time[1], current_time[1] .. current_time[2]) --Add request to the sorted set
        redis.call('EXPIRE', key, time_window) -- Set expiration time for sorted set
        return 1 -- Success: enough request available
    end
    return 0 -- Failure: not enough request available 
]]   

return {

    token_bucket_rl_min_alg = token_bucket_script_per_min_rl,
    token_bucket_rl_sec_alg = token_bucket_script_per_sec_rl,
    sliding_window_rl_alg = sliding_window_rl

}