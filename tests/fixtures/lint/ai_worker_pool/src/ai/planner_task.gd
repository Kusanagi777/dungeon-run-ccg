extends RefCounted

func start(work: Callable) -> int:
	return WorkerThreadPool.add_task(work)
