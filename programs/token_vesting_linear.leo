import token_registry.aleo;
import credits.aleo;

program token_vesting_linear_12345pm.aleo {

    record LockedTokensReceipt {
        owner: address,
        lock_id: field
    }

    struct LockedTokens {
        lock_id: field,
        token_id: field,
        locked_amount: u128,
        claimed_amount: u128,
        start_block: u32,
        blocks_count_per_part: u32
    }

    mapping locks: field => LockedTokens; // lock_id -> LockedTokens

    async transition create_lock_private (
        lock_id: field,
        t: token_registry.aleo/Token,
        amount: u128,
        receiver: address,
        public blocks_start: u32,
        public blocks_length: u32
    ) -> (token_registry.aleo/Token, LockedTokensReceipt, Future) {

        // Use the external program's function to transfer tokens
        let transfer_result: (token_registry.aleo/Token, Future) = token_registry.aleo/transfer_private_to_public(
            self.address,
            amount,
            t
        );

        let receipt: LockedTokensReceipt = LockedTokensReceipt {
            owner: receiver,
            lock_id: lock_id
        };

        return (
            transfer_result.0,
            receipt,
            f_create_lock_private(
                transfer_result.1,
                lock_id,
                t.token_id,
                blocks_length,
                amount,
                blocks_start
            )
        );    
    }
    
    async function f_create_lock_private(
            f0: Future,
            lock_id: field,
            token_id: field,
            block_length: u32,
            amount: u128,
            block_start: u32
        ) {
            f0.await();
            assert(!locks.contains(lock_id));

            locks.set(lock_id, LockedTokens {
                lock_id: lock_id,
                token_id: token_id,
                locked_amount: amount,
                claimed_amount: 0u128,
                start_block: block_start,
                blocks_count_per_part: block_length / 1000u32
            });
        }

    async transition claim (
        receipt: LockedTokensReceipt,
        locked: LockedTokens,
        amount: u128,
        is_authorized_token: bool,
        public current_block_height: u32 // Pass the current block height as an input
    ) -> (
        token_registry.aleo/Token,
        LockedTokensReceipt,
        Future
    ) {
        let claimed_amount: u128 = locked.claimed_amount + amount;
        assert_eq(receipt.lock_id, locked.lock_id);
        assert(claimed_amount <= locked.locked_amount);

        // Use the external program's function to transfer tokens
        let transfer_result: (token_registry.aleo/Token, Future) = 
            token_registry.aleo/transfer_public_to_private(
                locked.token_id,
                receipt.owner,
                amount,
                is_authorized_token
            );

        let claimed_part: u128 = (claimed_amount * 1000u128) / locked.locked_amount;

        return (
            transfer_result.0,
            receipt,
            f_claim(
                transfer_result.1,
                locked.lock_id,
                BHP256::hash_to_field(locked),
                claimed_part,
                claimed_amount,
                current_block_height // Pass the current block height to the function
            )
        );
    }

    async function f_claim(
        f0: Future,
        lock_id: field,
        lock_hash: field,
        claimed_amount_part: u128,
        claimed_amount: u128,
        current_block_height: u32 // Accept the current block height as an input
    ) {
        let lock: LockedTokens = locks.get(lock_id);
        assert_eq(lock_hash, BHP256::hash_to_field(lock));

        // Calculate available parts using the current block height
        let available_parts: u128 = ((current_block_height - lock.start_block) as u128 / lock.blocks_count_per_part as u128);
        assert(claimed_amount_part <= available_parts);

        locks.set(lock_id, LockedTokens {
            lock_id: lock.lock_id,
            token_id: lock.token_id,
            locked_amount: lock.locked_amount,
            claimed_amount: claimed_amount,
            start_block: lock.start_block,
            blocks_count_per_part: lock.blocks_count_per_part
        });

        f0.await();
    }
}