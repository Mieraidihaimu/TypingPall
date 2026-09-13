#!/usr/bin/env python3
"""Validate original bundled examples. Never executes imported user scripts."""
import argparse
import asyncio
import itertools
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import types

ROOT = Path(__file__).resolve().parents[1]
LESSONS = json.loads((ROOT / 'TypingPall/Content/lessons.json').read_text())


def check_python():
    modules = {}
    for lesson in LESSONS:
        if lesson['language'] != 'python':
            continue
        module = types.ModuleType(lesson['id'].replace('-', '_'))
        sys.modules[module.__name__] = module
        exec(compile(lesson['code'], lesson['id'], 'exec'), module.__dict__)
        modules[lesson['id']] = module
    m = modules
    rng = random.Random(42)
    for _ in range(100):
        text = ''.join(rng.choice('abc') for _ in range(rng.randrange(10)))
        expected = max((j-i for i in range(len(text)+1) for j in range(i,len(text)+1)
                        if len(set(text[i:j])) == j-i), default=0)
        assert m['py-sliding-window'].longest_unique(text) == expected
        values = sorted(rng.randrange(-5, 6) for _ in range(rng.randrange(10)))
        target = rng.randrange(-7, 8)
        pair = m['py-two-pointers'].pair_sum(values, target)
        if pair is None:
            assert not any(a+b == target for a,b in itertools.combinations(values, 2))
        else:
            a,b = pair
            assert a < b and values[a]+values[b] == target
        import bisect
        assert m['py-binary-search'].lower_bound(values, target) == bisect.bisect_left(values, target)
        rng.shuffle(values)
        expected = sum(sum(values[i:j]) == target for i in range(len(values)) for j in range(i+1,len(values)+1))
        assert m['py-prefix-sum'].count_subarrays(values, target) == expected
        expected = [next((j-i for j in range(i+1,len(values)) if values[j] > value),0) for i,value in enumerate(values)]
        assert m['py-monotonic-stack'].days_until_warmer(values) == expected
        k = rng.randrange(-1, 12)
        assert m['py-top-k'].largest_k(values,k) == (sorted(values,reverse=True)[:k] if k > 0 else [])
        nonnegative = [abs(v) for v in values]
        expected = max((sum(nonnegative[i] for i in range(len(values)) if mask & (1 << i))
                        for mask in range(1 << len(values)) if not mask & (mask << 1)), default=0)
        assert m['py-dp'].max_nonadjacent_sum(nonnegative) == expected
    Node = m['py-fast-slow'].Node
    first, second = Node(1), Node(2)
    first.next = second
    assert not m['py-fast-slow'].has_cycle(first)
    second.next = first
    assert m['py-fast-slow'].has_cycle(first)
    assert not m['py-fast-slow'].has_cycle(None)
    merge = m['py-intervals'].merge_intervals
    assert merge([]) == []
    assert merge([[1,3],[2,6],[8,10],[10,12]]) == [[1,6],[8,12]]
    graph = {0:[1,2],1:[2],2:[0,3],3:[]}
    assert m['py-bfs'].shortest_distances(graph,0) == {0:0,1:1,2:1,3:2}
    assert m['py-dfs'].reachable_nodes(graph,0) == {0,1,2,3}
    assert m['py-bfs'].shortest_distances({},0) == {0:0}
    for n in range(7):
        result = m['py-backtracking'].subsets(list(range(n)))
        assert len(result) == len({tuple(v) for v in result}) == 2**n
    uf = m['py-union-find'].UnionFind(5)
    assert uf.union(0,1) and uf.union(1,2)
    assert not uf.union(0,2)
    assert uf.find(0) == uf.find(2) != uf.find(3)
    assert m['py-comprehensions'].describe_even_squares([1,2,2,3,4]) == ([4,4,16],{0:4,1:4,2:16},{4,16})
    counts,groups = m['py-collections'].summarize_words(['a','bb','a'])
    assert counts['a'] == 2 and groups == {1:['a','a'],2:['bb']}
    assert list(m['py-generators'].batches(range(5),2)) == [[0,1],[2,3],[4]]
    try:
        list(m['py-generators'].batches([],0))
        raise AssertionError('Expected invalid batch size to fail')
    except ValueError:
        pass
    Task = m['py-dataclasses'].Task
    assert [t.name for t in m['py-dataclasses'].prioritize([Task('b',2),Task('a',2),Task('c',1)])] == ['a','b','c']
    assert m['py-thread-pool'].parallel_squares([1,2,3]) == [1,4,9]
    assert m['py-lock'].shared_counter() == 400
    assert asyncio.run(m['py-asyncio'].run_batch([1,2,3])) == [2,4,6]
    print(f'PASS: {len(modules)} Python lessons, including randomized algorithm checks')


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
    args = parser.parse_args()
    assert len(LESSONS) == len({lesson['id'] for lesson in LESSONS}) == 37
    try:
        check_python()
        check_compiled(args.require_all)
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr)
        raise
