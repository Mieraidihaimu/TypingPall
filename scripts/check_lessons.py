#!/usr/bin/env python3
"""Validate original bundled examples. Never executes imported user scripts."""
import argparse
import asyncio
import bisect
from fractions import Fraction
import itertools
import json
import math
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import threading
import types

ROOT = Path(__file__).resolve().parents[1]
LESSONS = json.loads((ROOT / 'TypingPall/Content/lessons.json').read_text())
TRACKS = {'leetcode', 'lowLevelDesign', 'languages'}
CHECKS = {}
MUTATION_TIMEOUT_SECONDS = 3


def checks(lesson_id):
    def register(function):
        CHECKS[lesson_id] = function
        return function
    return register


def random_values(rng, size=10):
    return [rng.randint(-5, 5) for _ in range(rng.randrange(size))]


def random_graph(rng, size=6):
    return {node: rng.sample(range(size), rng.randrange(size)) for node in range(size)}


def reference_distances(graph, start):
    distances, changed = {start: 0}, True
    while changed:
        changed = False
        for node, neighbors in graph.items():
            for neighbor in neighbors:
                if node in distances and distances[node] + 1 < distances.get(neighbor, len(graph) + 1):
                    distances[neighbor], changed = distances[node] + 1, True
    return distances


def random_tree(rng, make_node, size=9):
    nodes = [make_node(0)]
    for value in range(1, rng.randint(1, size)):
        free = [(node, side) for node in nodes for side in ('left', 'right') if getattr(node, side) is None]
        node, side = rng.choice(free)
        child = make_node(value)
        setattr(node, side, child)
        nodes.append(child)
    return nodes


def undirected_tree(nodes):
    graph = {node.value: [] for node in nodes}
    for node in nodes:
        for child in (node.left, node.right):
            if child is not None:
                graph[node.value].append(child.value)
                graph[child.value].append(node.value)
    return graph


@checks('py-sliding-window')
def check_sliding_window(m, rng):
    for _ in range(200):
        text = ''.join(rng.choice('abc') for _ in range(rng.randrange(10)))
        expected = max((j - i for i in range(len(text) + 1) for j in range(i, len(text) + 1)
                        if len(set(text[i:j])) == j - i), default=0)
        assert m.longest_unique(text) == expected


@checks('py-sliding-window-shrink')
def check_shrinking_window(m, rng):
    for _ in range(200):
        text = ''.join(rng.choice('abcd') for _ in range(rng.randrange(12)))
        k = rng.randrange(4)
        expected = max((j - i for i in range(len(text) + 1) for j in range(i, len(text) + 1)
                        if len(set(text[i:j])) <= k), default=0)
        assert m.longest_with_k_distinct(text, k) == expected


@checks('py-two-pointers')
def check_pair_sum(m, rng):
    for _ in range(200):
        values = sorted(random_values(rng))
        target = rng.randint(-7, 7)
        pair = m.pair_sum(values, target)
        if pair is None:
            assert not any(a + b == target for a, b in itertools.combinations(values, 2))
        else:
            a, b = pair
            assert a < b and values[a] + values[b] == target


@checks('py-fast-slow')
def check_fast_slow(m, rng):
    assert not m.has_cycle(None)
    for length in range(1, 8):
        for loop_to in [None, *range(length)]:
            nodes = [m.Node(index) for index in range(length)]
            for node, following in zip(nodes, nodes[1:]):
                node.next = following
            if loop_to is not None:
                nodes[-1].next = nodes[loop_to]
            assert m.has_cycle(nodes[0]) == (loop_to is not None)


@checks('py-reverse-list')
def check_reverse_between(m, rng):
    for n in range(1, 7):
        for left in range(1, n + 1):
            for right in range(left, n + 1):
                head = None
                for value in reversed(range(n)):
                    head = m.Node(value, head)
                result, node = [], m.reverse_between(head, left, right)
                while node is not None and len(result) <= n:
                    result.append(node.value)
                    node = node.next
                values = list(range(n))
                assert result == values[:left - 1] + values[left - 1:right][::-1] + values[right:]


@checks('py-intervals')
def check_intervals(m, rng):
    assert m.merge_intervals([]) == []
    assert m.merge_intervals([[1, 3], [2, 6], [8, 10], [10, 12]]) == [[1, 6], [8, 12]]
    for _ in range(200):
        intervals = [sorted((rng.randint(0, 9), rng.randint(0, 9))) for _ in range(rng.randrange(6))]
        snapshot = [list(interval) for interval in intervals]
        runs = []  # doubled coordinates keep [1, 2] and [3, 4] apart
        for point in sorted({p for start, end in intervals for p in range(2 * start, 2 * end + 1)}):
            if runs and point == runs[-1][1] + 1:
                runs[-1][1] = point
            else:
                runs.append([point, point])
        assert m.merge_intervals(intervals) == [[start // 2, end // 2] for start, end in runs]
        assert intervals == snapshot


@checks('py-intervals-by-end')
def check_min_removals(m, rng):
    for _ in range(200):
        intervals = [sorted(rng.sample(range(10), 2)) for _ in range(rng.randrange(9))]

        def compatible(chosen):
            ordered = sorted(chosen)
            return all(first[1] <= second[0] for first, second in zip(ordered, ordered[1:]))
        kept = max(size for size in range(len(intervals) + 1)
                   for chosen in itertools.combinations(intervals, size) if compatible(chosen))
        assert m.min_removals(intervals) == len(intervals) - kept


@checks('py-binary-search')
def check_lower_bound(m, rng):
    for _ in range(200):
        values = sorted(random_values(rng))
        target = rng.randint(-7, 7)
        assert m.lower_bound(values, target) == bisect.bisect_left(values, target)


@checks('py-upper-bound')
def check_upper_bound(m, rng):
    for _ in range(200):
        values = sorted(random_values(rng))
        target = rng.randint(-7, 7)
        assert m.upper_bound(values, target) == bisect.bisect_right(values, target)


@checks('py-binary-search-closed')
def check_closed_search(m, rng):
    for _ in range(200):
        values = sorted(random_values(rng))
        target = rng.randint(-7, 7)
        index = m.find_index(values, target)
        if target in values:
            assert 0 <= index < len(values) and values[index] == target
        else:
            assert index == -1


@checks('py-binary-search-answer')
def check_search_on_answer(m, rng):
    for _ in range(200):
        loads = [rng.randint(1, 20) for _ in range(rng.randint(1, 6))]
        hours = rng.randint(len(loads), len(loads) + 15)
        expected = next(speed for speed in range(1, max(loads) + 1) if sum(-(-load // speed) for load in loads) <= hours)
        assert m.min_speed(loads, hours) == expected


@checks('py-prefix-sum')
def check_prefix_sum(m, rng):
    for _ in range(200):
        values = random_values(rng)
        target = rng.randint(-7, 7)
        expected = sum(sum(values[i:j]) == target for i in range(len(values)) for j in range(i + 1, len(values) + 1))
        assert m.count_subarrays(values, target) == expected


@checks('py-monotonic-stack')
def check_days_until_warmer(m, rng):
    for _ in range(200):
        values = random_values(rng)
        expected = [next((j - i for j in range(i + 1, len(values)) if values[j] > value), 0) for i, value in enumerate(values)]
        assert m.days_until_warmer(values) == expected


@checks('py-monotonic-increasing')
def check_largest_rectangle(m, rng):
    for _ in range(200):
        heights = [rng.randint(0, 6) for _ in range(rng.randrange(9))]
        expected = max((min(heights[i:j]) * (j - i) for i in range(len(heights))
                        for j in range(i + 1, len(heights) + 1)), default=0)
        assert m.largest_rectangle(heights) == expected


@checks('py-bfs')
def check_bfs(m, rng):
    assert m.shortest_distances({}, 0) == {0: 0}
    for _ in range(200):
        graph = random_graph(rng)
        assert m.shortest_distances(graph, 0) == reference_distances(graph, 0)


@checks('py-tree-bfs')
def check_level_order(m, rng):
    assert m.level_order(None) == []
    for _ in range(200):
        nodes = random_tree(rng, m.TreeNode)
        levels = []

        def collect(node, depth):  # pre-order visits each level left to right
            if node is not None:
                if depth == len(levels):
                    levels.append([])
                levels[depth].append(node.value)
                collect(node.left, depth + 1)
                collect(node.right, depth + 1)
        collect(nodes[0], 0)
        assert m.level_order(nodes[0]) == levels


@checks('py-grid-traversal')
def check_grid_distances(m, rng):
    steps = ((1, 0), (-1, 0), (0, 1), (0, -1))
    for _ in range(200):
        grid = [''.join(rng.choice('E......##') for _ in range(5)) for _ in range(4)]
        cells = {(r, c) for r in range(4) for c in range(5) if grid[r][c] != '#'}
        graph = {(r, c): [(r + dr, c + dc) for dr, dc in steps if (r + dr, c + dc) in cells] for r, c in cells}
        graph['exits'] = [(r, c) for r, c in cells if grid[r][c] == 'E']  # one hop before every exit
        distances = reference_distances(graph, 'exits')
        assert m.distances_to_exit(grid) == [[distances.get((r, c), 0) - 1 for c in range(5)] for r in range(4)]


@checks('py-topological-sort')
def check_course_order(m, rng):
    for _ in range(200):
        n = rng.randint(1, 6)
        edges = [(rng.randrange(n), rng.randrange(n)) for _ in range(rng.randrange(2 * n))]
        acyclic = any(all(order.index(a) < order.index(b) for a, b in edges) for order in itertools.permutations(range(n)))
        result = m.course_order(n, edges)
        if acyclic:
            assert sorted(result) == list(range(n))
            assert all(result.index(a) < result.index(b) for a, b in edges)
        else:
            assert result == []


@checks('py-dfs')
def check_dfs(m, rng):
    for _ in range(200):
        graph = random_graph(rng)
        assert m.reachable_nodes(graph, 0) == set(reference_distances(graph, 0))


@checks('py-tree-dfs')
def check_diameter(m, rng):
    assert m.diameter(None) == 0
    for _ in range(200):
        nodes = random_tree(rng, m.TreeNode)
        graph = undirected_tree(nodes)
        assert m.diameter(nodes[0]) == max(max(reference_distances(graph, node).values()) for node in graph)


@checks('py-backtracking')
def check_subsets(m, rng):
    for n in range(7):
        expected = sorted(c for size in range(n + 1) for c in itertools.combinations(range(n), size))
        assert sorted(map(tuple, m.subsets(list(range(n))))) == expected


@checks('py-top-k')
def check_top_k(m, rng):
    for _ in range(200):
        values = random_values(rng)
        k = rng.randrange(-1, 12)
        assert m.largest_k(values, k) == (sorted(values, reverse=True)[:k] if k > 0 else [])


@checks('py-union-find')
def check_union_find(m, rng):
    for _ in range(200):
        n = rng.randrange(1, 12)
        uf, labels = m.UnionFind(n), list(range(n))
        for _ in range(2 * n):
            first, second = rng.randrange(n), rng.randrange(n)
            joined = labels[first] != labels[second]
            assert uf.union(first, second) == joined
            if joined:
                old = labels[second]
                labels = [labels[first] if label == old else label for label in labels]
        # find() flattens trees, so compare groups only after the unions
        assert all((uf.find(a) == uf.find(b)) == (labels[a] == labels[b]) for a in range(n) for b in range(n))


@checks('py-dp')
def check_max_nonadjacent_sum(m, rng):
    for _ in range(200):
        values = [abs(value) for value in random_values(rng)]
        expected = max((sum(values[i] for i in range(len(values)) if mask & (1 << i))
                        for mask in range(1 << len(values)) if not mask & (mask << 1)), default=0)
        assert m.max_nonadjacent_sum(values) == expected


@checks('py-knapsack-01')
def check_knapsack(m, rng):
    for _ in range(200):
        items = [(rng.randint(1, 6), rng.randint(0, 9)) for _ in range(rng.randrange(9))]
        capacity = rng.randint(0, 15)
        expected = max(sum(value for _, value in chosen) for size in range(len(items) + 1)
                       for chosen in itertools.combinations(items, size) if sum(weight for weight, _ in chosen) <= capacity)
        assert m.best_value(items, capacity) == expected


@checks('py-coin-change')
def check_fewest_coins(m, rng):
    for _ in range(200):
        coins = rng.sample(range(1, 13), rng.randint(1, 4))
        amount = rng.randint(0, 30)
        graph = {total: [total + coin for coin in coins if total + coin <= amount] for total in range(amount + 1)}
        assert m.fewest_coins(coins, amount) == reference_distances(graph, 0).get(amount, -1)


def expect_error(error, action):
    try:
        action()
    except error:
        return
    raise AssertionError(f'expected {error.__name__}')


class Gate:
    """A lock that lets nobody in until every thread is waiting at it."""

    def __init__(self, parties):
        self.barrier = threading.Barrier(parties, timeout=2)
        self.lock = threading.Lock()
        self.entered = 0

    def __enter__(self):
        self.barrier.wait()
        self.lock.acquire()
        self.entered += 1

    def __exit__(self, *exc_info):
        self.lock.release()


@checks('lld-factory')
def check_factory(m, rng):
    email = m.create('email')
    assert isinstance(email, m.Email) and email is not m.create('email')
    assert email.send('ana', 'hi') == 'email ana: hi'
    assert m.create('sms').send('bo', 'x' * 200) == 'sms bo: ' + 'x' * 160
    expect_error(ValueError, lambda: m.create('fax'))

    @m.register('push')
    class Push:
        pass
    assert isinstance(m.create('push'), Push)


@checks('lld-builder')
def check_builder(m, rng):
    builder = m.QueryBuilder('users').take(10).where('age > 30').select('id', 'name').where('active')
    query = builder.build()
    assert query == m.Query('users', ('id', 'name'), ('age > 30', 'active'), 10)
    builder.select('email')
    assert query.columns == ('id', 'name') and builder.build().columns == ('id', 'name', 'email')
    expect_error(ValueError, m.QueryBuilder('users').where('active').build)


@checks('lld-singleton')
def check_singleton(m, rng):
    first = m.Config()
    first.settings['theme'] = 'dark'
    assert m.Config() is first and m.Config().settings == {'theme': 'dark'}
    # Both threads pass the unlocked check before either may build.
    m.Config._instance, m.Config._lock = None, Gate(2)
    created = []
    workers = [threading.Thread(target=lambda: created.append(m.Config())) for _ in range(2)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()
    assert m.Config._lock.entered == 2 and len(created) == 2 and created[0] is created[1]


@checks('lld-adapter')
def check_adapter(m, rng):
    gateway = m.VendorGateway()
    adapter = m.GatewayAdapter(gateway)
    assert adapter.pay(12.34) == 'ch_1' and adapter.pay(0.29) == 'ch_2'
    assert gateway.charges == [(1234, 'USD'), (29, 'USD')]
    expect_error(ValueError, lambda: adapter.pay(0))


@checks('lld-decorator')
def check_decorator(m, rng):
    for _ in range(200):
        item, cost, words = m.Pizza(), 8.0, 'pizza'
        for _ in range(rng.randrange(5)):
            if rng.random() < 0.5:
                item, cost, words = m.Cheese(item), cost + 1.5, words + ', cheese'
            else:
                item, cost, words = m.HappyHour(item), cost * 0.8, words + ' (happy hour)'
        assert math.isclose(item.cost(), cost) and item.describe() == words


@checks('lld-composite')
def check_composite(m, rng):
    for _ in range(200):
        root = m.Folder('root')
        folders, total = [root], 0
        for index in range(rng.randrange(12)):
            parent = rng.choice(folders)
            if rng.random() < 0.4:
                folders.append(m.Folder(f'd{index}'))
                parent.add(folders[-1])
            else:
                size = rng.randint(0, 9)
                parent.add(m.File(f'f{index}', size))
                total += size
        assert root.size() == total
    assert m.Folder('a').add(m.File('x', 2)).add(m.File('y', 3)).size() == 5


@checks('lld-strategy')
def check_strategy(m, rng):
    class Fixed:
        def apply(self, prices):
            return 42
    for _ in range(200):
        prices = [rng.randint(0, 20) for _ in range(rng.randrange(6))]
        assert m.Checkout(m.FullPrice()).total(prices) == sum(prices)
        assert m.Checkout(m.PercentOff(25)).total(prices) == sum(prices) * 0.75
        assert m.Checkout(m.CheapestFree()).total(prices) == sum(prices) - min(prices, default=0)
        assert m.Checkout(Fixed()).total(prices) == 42
    checkout = m.Checkout(m.FullPrice())
    checkout.pricing = m.PercentOff(50)
    assert checkout.total([10, 30]) == 20


@checks('lld-state')
def check_state(m, rng):
    replies = {('idle', 'insert_coin'): ('paid', 'coin accepted'), ('idle', 'press'): ('idle', 'insert a coin first'),
               ('paid', 'insert_coin'): ('paid', 'coin returned'), ('paid', 'press'): ('idle', 'dispensed')}
    for _ in range(200):
        machine, state = m.VendingMachine(), 'idle'
        for _ in range(rng.randrange(10)):
            event = rng.choice(['insert_coin', 'press'])
            state, reply = replies[state, event]
            assert getattr(machine, event)() == reply
    first, second = m.VendingMachine(), m.VendingMachine()
    first.insert_coin()
    assert second.press() == 'insert a coin first'


@checks('lld-observer')
def check_observer(m, rng):
    feed, seen = m.PriceFeed(), []

    def leave_after_first(price):
        seen.append(('leaver', price))
        unsubscribe_leaver()
    unsubscribe_leaver = feed.subscribe(leave_after_first)
    unsubscribe_logger = feed.subscribe(lambda price: seen.append(('logger', price)))
    feed.subscribe(lambda price: seen.append(('audit', price)))
    feed.publish(1)
    unsubscribe_logger()
    feed.publish(2)
    assert seen == [('leaver', 1), ('logger', 1), ('audit', 1), ('audit', 2)]
    for _ in range(200):
        feed, log, expected, unsubscribers = m.PriceFeed(), [], [], {}
        for step in range(rng.randrange(12)):
            if rng.random() < 0.4:
                unsubscribers[step] = feed.subscribe(lambda price, step=step: log.append((step, price)))
            elif rng.random() < 0.5 and unsubscribers:
                unsubscribers.pop(rng.choice(list(unsubscribers)))()
            else:
                feed.publish(step)
                expected += [(name, step) for name in unsubscribers]
        assert log == expected


@checks('lld-command')
def check_command(m, rng):
    for _ in range(200):
        editor, history, future = m.Editor(), [''], []
        for _ in range(rng.randrange(12)):
            action = rng.random()
            if action < 0.5:
                doc = history[-1]
                position = rng.randint(0, len(doc))
                text = ''.join(rng.choice('ab') for _ in range(rng.randint(1, 3)))
                editor.run(m.Insert(position, text))
                history.append(doc[:position] + text + doc[position:])
                future.clear()
            elif action < 0.75:
                editor.undo()
                if len(history) > 1:
                    future.append(history.pop())
            else:
                editor.redo()
                if future:
                    history.append(future.pop())
            assert editor.doc == history[-1]


@checks('lld-chain')
def check_chain(m, rng):
    chain, limits = m.approval_chain(), [('manager', 1_000), ('director', 10_000), ('cfo', 100_000)]
    for amount in [0, 1_000, 1_001, 10_000, 10_001, 100_000, 100_001] + [rng.randint(0, 200_000) for _ in range(200)]:
        assert chain.approve(amount) == next((title for title, limit in limits if amount <= limit), 'rejected')
    assert m.Approver('solo', 5).approve(6) == 'rejected'


@checks('lld-lru-cache')
def check_lru_cache(m, rng):
    for _ in range(200):
        capacity = rng.randint(1, 3)
        cache, recent, values = m.LRUCache(capacity), [], {}  # recent runs from least to most recent
        for _ in range(rng.randrange(15)):
            key = rng.randrange(5)
            if rng.random() < 0.5:
                assert cache.get(key) == (values[key] if key in recent else None)
                if key in recent:
                    recent.remove(key)
                    recent.append(key)
            else:
                values[key] = rng.randrange(100)
                cache.put(key, values[key])
                if key in recent:
                    recent.remove(key)
                recent.append(key)
                if len(recent) > capacity:
                    recent.pop(0)
        assert list(cache.items) == recent


@checks('lld-rate-limiter')
def check_rate_limiter(m, rng):
    for _ in range(200):
        now = [rng.randint(0, 100)]
        capacity, rate = rng.randint(1, 4), rng.choice([0.5, 1, 2])
        bucket = m.TokenBucket(capacity, rate, lambda: now[0])
        tokens, updated = Fraction(capacity), now[0]
        for _ in range(rng.randrange(15)):
            now[0] += rng.choice([0, 0, 0.25, 0.5, 1, 3])
            tokens = min(capacity, tokens + Fraction(now[0] - updated) * Fraction(rate))
            updated, allowed = now[0], tokens >= 1
            tokens -= allowed
            assert bucket.allow() == allowed


@checks('py-comprehensions')
def check_comprehensions(m, rng):
    assert m.describe_even_squares([1, 2, 2, 3, 4]) == ([4, 4, 16], {0: 4, 1: 4, 2: 16}, {4, 16})


@checks('py-collections')
def check_collections(m, rng):
    counts, groups = m.summarize_words(['a', 'bb', 'a'])
    assert counts['a'] == 2 and groups == {1: ['a', 'a'], 2: ['bb']}


@checks('py-generators')
def check_generators(m, rng):
    assert list(m.batches(range(5), 2)) == [[0, 1], [2, 3], [4]]
    try:
        list(m.batches([], 0))
        raise AssertionError('Expected invalid batch size to fail')
    except ValueError:
        pass


@checks('py-dataclasses')
def check_dataclasses(m, rng):
    Task = m.Task
    assert [t.name for t in m.prioritize([Task('b', 2), Task('a', 2), Task('c', 1)])] == ['a', 'b', 'c']


@checks('py-thread-pool')
def check_thread_pool(m, rng):
    assert m.parallel_squares([1, 2, 3]) == [1, 4, 9]


@checks('py-lock')
def check_lock(m, rng):
    assert m.shared_counter() == 400


@checks('py-asyncio')
def check_asyncio(m, rng):
    assert asyncio.run(m.run_batch([1,2,3])) == [2,4,6]


def load_module(lesson_id, code):
    module = types.ModuleType(lesson_id.replace('-', '_'))
    sys.modules[module.__name__] = module  # dataclasses look up their module here
    exec(compile(code, lesson_id, 'exec'), module.__dict__)
    return module


def run_check(lesson_id, code):
    CHECKS[lesson_id](load_module(lesson_id, code), random.Random(42))


def check_python():
    python_ids = {lesson['id'] for lesson in LESSONS if lesson['language'] == 'python'}
    assert python_ids == CHECKS.keys(), ('unchecked', sorted(python_ids - CHECKS.keys()), 'unknown', sorted(CHECKS.keys() - python_ids))
    for lesson in LESSONS:
        if lesson['id'] in CHECKS:
            run_check(lesson['id'], lesson['code'])
    print(f'PASS: {len(python_ids)} Python lessons, including randomized algorithm checks')


def typed_lines(lesson):
    comment = '#' if lesson['language'] == 'python' else '//'
    lines = lesson['code'].split('\n')
    typed = {index for index, line in enumerate(lines) if line.strip() and not line.lstrip().startswith(comment)}
    return typed - set(lesson.get('scaffoldLineIndices', []))


def indentation(line):
    return line[:len(line) - len(line.lstrip())]


def check_metadata():
    by_id = {lesson['id']: lesson for lesson in LESSONS}
    track_of_category = {}
    for lesson in LESSONS:
        where, lines, typed = lesson['id'], lesson['code'].split('\n'), typed_lines(lesson)
        assert lesson.get('track') in TRACKS, (where, 'track')
        assert track_of_category.setdefault(lesson['category'], lesson['track']) == lesson['track'], (where, 'category spans tracks')
        for field in ('triggers', 'prompts', 'pitfalls', 'contrastWith', 'anchors', 'keyLineIndices', 'mutations'):
            assert lesson.get(field, [None]), (where, field, 'is empty')
        texts = [lesson.get(field, '-') for field in ('family', 'invariant', 'mantra')]
        texts += lesson.get('triggers', []) + lesson.get('prompts', []) + lesson.get('pitfalls', [])
        texts += [part for anchor in lesson.get('anchors', []) for part in (anchor['name'], anchor['trick'])]
        texts += [mutation['explanation'] for mutation in lesson.get('mutations', [])]
        assert all(text.strip() for text in texts), (where, 'blank text')
        assert set(lesson.get('keyLineIndices', [])) <= typed, (where, 'keyLineIndices')
        for other in lesson.get('contrastWith', []):
            assert other != where and where in by_id.get(other, {}).get('contrastWith', []), (where, 'contrastWith must be mutual', other)
        for mutation in lesson.get('mutations', []):
            assert where in CHECKS and mutation['line'] in typed, (where, 'mutation', mutation['line'])
            original, replacement = lines[mutation['line']], mutation['replacement']
            assert replacement != original and indentation(replacement) == indentation(original), (where, 'mutation', mutation['line'])
    print(f"PASS: metadata for {sum('family' in lesson for lesson in LESSONS)} pattern lessons")


def mutation_survives(lesson_id, code):
    try:
        result = subprocess.run([sys.executable, str(Path(__file__).resolve()), '--run-check', lesson_id],
                                input=code, capture_output=True, text=True, timeout=MUTATION_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        return False  # several planted bugs loop forever
    return result.returncode == 0


def check_mutations():
    planted = 0
    for lesson in LESSONS:
        for mutation in lesson.get('mutations', []):
            lines = lesson['code'].split('\n')
            lines[mutation['line']] = mutation['replacement']
            code = '\n'.join(lines)
            compile(code, lesson['id'], 'exec')
            assert not mutation_survives(lesson['id'], code), f"{lesson['id']} line {mutation['line']}: planted bug passes the checks"
            planted += 1
    print(f'PASS: {planted} planted bugs fail their lesson checks')


EXPECTED = {
    'cpp-vectors':'2 3', 'cpp-map':'2 1', 'cpp-raii':'10 20', 'cpp-lambda':'a b c',
    'cpp-lock':'200', 'cpp-condition':'42', 'cpp-future':'55',
    'go-slices':'2', 'go-errors':'8080', 'go-methods':'3', 'go-interfaces':'task: practice', 'go-channels':'1\n4\n9',
    'rust-borrow':'practice\npractice patterns', 'rust-result':'[1, 2, 3]',
    'rust-iterators':'[4, 16]', 'rust-enums':'0', 'rust-shared-state':'4',
}


def check_compiled(require_all):
    missing = []
    with tempfile.TemporaryDirectory(prefix='typingpall-lessons-') as directory:
        folder = Path(directory)
        env = dict(os.environ, GOCACHE=str(folder/'go-cache'), GOPROXY='off', GOTOOLCHAIN='local')
        for language, tool, extension in [('cpp','clang++','cpp'),('go','go','go'),('rust','rustc','rs')]:
            compiler = shutil.which(tool)
            if not compiler:
                missing.append(tool)
                print(f'SKIP: {language} execution ({tool} is not installed)')
                continue
            examples = [lesson for lesson in LESSONS if lesson['language'] == language]
            for lesson in examples:
                source = folder / (lesson['id'] + '.' + extension)
                binary = folder / lesson['id']
                source.write_text(lesson['code'])
                if language == 'cpp':
                    command = [compiler,'-std=c++17','-pthread',str(source),'-o',str(binary)]
                elif language == 'go':
                    command = [compiler,'build','-o',str(binary),str(source)]
                else:
                    command = [compiler,'--edition=2021',str(source),'-o',str(binary)]
                subprocess.run(command, check=True, env=env, capture_output=True, text=True, timeout=120)
                output = subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=10).stdout.strip()
                assert output == EXPECTED[lesson['id']], (lesson['id'], output)
            print(f'PASS: {len(examples)} {language} lessons compiled and executed')
    if missing and require_all:
        raise SystemExit('Missing required compilers: ' + ', '.join(missing))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-all', action='store_true', help='Fail if any language compiler is unavailable')
    parser.add_argument('--run-check', metavar='LESSON_ID', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.run_check:
        run_check(args.run_check, sys.stdin.read())
        sys.exit()
    assert len(LESSONS) == len({lesson['id'] for lesson in LESSONS}), 'duplicate lesson ids'
    try:
        check_metadata()
        check_python()
        check_mutations()
        check_compiled(args.require_all)
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr)
        raise
