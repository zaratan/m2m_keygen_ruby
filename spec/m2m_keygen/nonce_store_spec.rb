# typed: false

describe M2mKeygen::NonceStore do
  it 'is an abstract interface that concrete stores must implement' do
    incomplete_store_class = Class.new { include M2mKeygen::NonceStore }

    expect { incomplete_store_class.new.add('n', ttl: 1) }.to raise_error(
      NotImplementedError,
    )
  end
end

describe M2mKeygen::NonceStore::Memory do
  subject(:store) { described_class.new }

  describe '#add' do
    it 'returns true the first time a nonce is recorded' do
      expect(store.add('abc', ttl: 60)).to be(true)
    end

    it 'returns false on a sequential replay of the same nonce' do
      store.add('abc', ttl: 60)

      expect(store.add('abc', ttl: 60)).to be(false)
    end

    it 'records a racing nonce exactly once across many threads and rounds' do
      thread_count = 12

      100.times do |round|
        nonce = "racing-nonce-#{round}"
        results = Queue.new
        threads =
          Array.new(thread_count) do
            Thread.new { results << store.add(nonce, ttl: 60) }
          end
        threads.each(&:join)
        outcomes = Array.new(thread_count) { results.pop }

        expect(outcomes.count(true)).to eq(1)
      end
    end

    it 'purges an expired entry so the nonce becomes reusable' do
      store.add('abc', ttl: -1)

      expect(store.add('abc', ttl: 60)).to be(true)
    end

    it 'keeps an entry rejecting replays until its ttl elapses' do
      store.add('abc', ttl: 60)

      expect(store.add('abc', ttl: 60)).to be(false)
    end

    it 'evicts the entry closest to expiring once at capacity, keeping the store bounded' do
      bounded_store = described_class.new(max_size: 2)
      bounded_store.add('first', ttl: 1)
      bounded_store.add('second', ttl: 1_000)

      bounded_store.add('third', ttl: 1_000)

      expect(bounded_store.add('second', ttl: 1_000)).to be(false)
      expect(bounded_store.add('first', ttl: 1_000)).to be(true)
    end
  end
end

describe M2mKeygen::NonceStore::Disabled do
  subject(:store) { described_class.new }

  describe '#add' do
    it 'always returns true, even on a repeated call with the same nonce' do
      expect(store.add('abc', ttl: 60)).to be(true)
      expect(store.add('abc', ttl: 60)).to be(true)
    end

    it 'returns true even for an empty nonce' do
      expect(store.add('', ttl: 60)).to be(true)
    end
  end
end
