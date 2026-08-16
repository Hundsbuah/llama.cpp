#pragma once

#include "llama.h"

#include "common.h"

#include <cstdint>
#include <vector>

enum common_reasoning_budget_state {
    REASONING_BUDGET_IDLE,          // waiting for start sequence
    REASONING_BUDGET_INTRO_FORCING, // forcing the intro/announcement message
    REASONING_BUDGET_COUNTING,      // counting down tokens
    REASONING_BUDGET_SOFT_PENDING,  // soft threshold crossed, waiting for a newline boundary
    REASONING_BUDGET_SOFT_FORCING,  // forcing the soft warning message
    REASONING_BUDGET_HARD_PENDING,  // budget exhausted, waiting (bounded) for a paragraph boundary
    REASONING_BUDGET_FORCING,       // forcing budget message + end sequence
    REASONING_BUDGET_WAITING_UTF8,  // budget exhausted, waiting for UTF-8 completion
    REASONING_BUDGET_DONE,          // passthrough until a new start sequence re-arms the sampler
};

// Creates a reasoning budget sampler that limits token generation inside a
// reasoning block (e.g. between <think> and </think>).
//
// State machine:
// IDLE -> INTRO_FORCING -> COUNTING -> SOFT_PENDING -> SOFT_FORCING
//      -> COUNTING -> HARD_PENDING -> WAITING_UTF8 -> FORCING -> DONE
//
// The soft and intro forced tokens do not count against the budget. If the hard
// budget expires while a soft warning is pending, the hard-cutoff path wins.
// With grace_tokens > 0, exhaustion waits for a paragraph boundary for at most
// grace_tokens generated tokens. UTF-8 completion is still respected before a
// forced hard sequence begins.
struct llama_sampler * common_reasoning_budget_init(
        const struct llama_vocab        * vocab,
        const std::vector<llama_tokens> & start_seqs,
        const std::vector<llama_tokens> & end_seqs,
        const llama_tokens              & forced_tokens,
        const llama_tokens              & soft_forced_tokens,
        const llama_tokens              & intro_forced_tokens,
        int32_t                           budget,
        float                             soft_ratio = -1.0f,
        int32_t                           grace_tokens = 0,
        common_reasoning_budget_state     initial_state = REASONING_BUDGET_IDLE);

// Compatibility overload for current-upstream callers that only use the hard budget.
struct llama_sampler * common_reasoning_budget_init(
        const struct llama_vocab        * vocab,
        const std::vector<llama_tokens> & start_seqs,
        const std::vector<llama_tokens> & end_seqs,
        const llama_tokens              & forced_tokens,
        int32_t                           budget,
        common_reasoning_budget_state     initial_state = REASONING_BUDGET_IDLE);

common_reasoning_budget_state common_reasoning_budget_get_state(const struct llama_sampler * smpl);

// The end sequence that transitioned the sampler to DONE, or nullptr if none
// was recorded. Cleared when a new start sequence re-arms the sampler.
const llama_tokens * common_reasoning_budget_get_end_match(const struct llama_sampler * smpl);

// Manually transition an active reasoning budget sampler into hard FORCING.
// Returns true if a transition occurred.
bool common_reasoning_budget_force(struct llama_sampler * smpl);
