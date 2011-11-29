def in_queue(id)
	queue = Queue.get(id)
	return true if queue
	return false
end