extends RefCounted

func run(work: Callable) -> int:
	return WorkerThreadPool.add_task(work)
