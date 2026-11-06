## Must not hit: `*_planner_task.gd` is where the worker lives (ADR-0006).
extends RefCounted

func start(work: Callable) -> int:
	return WorkerThreadPool.add_task(work)
