# Extract a delimited fragment (subtree) from the queue.
def extract(queue):
    results = []
    depth = 0
    for element in queue:
        if element[0] == "SRT":
            return []
        if element[0] == "INC":
            depth = depth + 1
        if element[0] == "DEC":
            if depth == 0:
                return results
            depth = depth - 1
        results.append(element)
        if depth == 0:
            return results
    return results

# Generate a list of variable bindings from the current queue and a pattern.
def match(pattern, queue, context=None):
    if context == None:
        context = {}
    if peek(queue) == None:
        return context
    for element in pattern:
        if element[0] == "VAR":
            variable = element[1]
            value    = extract(queue)
            if variable in context:
                if context[variable] != value:
                    return None
                queue = dequeue(queue, len(context[variable]))
            else:
                if len(value) == 0:
                    return None
                context[variable] = value
                queue             = dequeue(queue, len(context[variable]))
        elif element != peek(queue):
            return None
        else:
            queue = dequeue(queue)
    return context

# Fill in a pattern with variables in it using a list of variable bindings.
def construct(pattern, context):
    results = []
    for element in pattern:
        if element[0] == "VAR":
            if element[1] in context:
                for element in context[element[1]]:
                    results.append(element)
            else:
                results.append(element)
        else:
            results.append(element)
    return results

# Apply a pattern/replacement rule to the queue.
def apply(queue, rules, pattern, replacement):
    context = match(pattern, queue)
    if context == None:
        return (False, roll(queue))
    pattern = construct(pattern, context)
    if not pattern:
        return (False, roll(queue))
    replacement = construct(replacement, context)
    return (True, enqueue(dequeue(queue, len(pattern)), replacement))