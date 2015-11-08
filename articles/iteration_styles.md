[date: 2013-09-22]

# "Iterating over a list and filtering" OR "Iterating over a filtered list"

## Noticing a pattern
The other day, I was working on some list-processing code. The system was serializing a set of commands to send to another server for further execution. Only a subset of the commands needed to be sent, so each serialization routine was responsible for filtering its child objects. I noticed an interesting pattern around the filtering, and I started thinking.

## Processing a list
Suppose I'm writing a system that manages items and actions on those items. We might have a class called Command. Each of these commands represents one of four types of actions: Update, Create, Contract or Expand.

```ruby
class Command
  attr_accessor :type
  def to_json
    #generate json here
  end
end
```

In my program, I get an unfiltered list of these that I need to send to another system. I could send them individually, but I want to instead batch them up into a single message.

### Only interested in a subset
But, the other system isn't interested in all the types of commands, just Updating and Creating. The other types, Expanding and Contracting, have slightly more complex rules around them, so we are handling them separately.

### Filtering with "next if *condition*" statements

This is a very common problem that comes up in code, and there are different ways to solve it. In this situation, the programmers chose to use the following construct, iterating with Enumerable#each and guarding against the undesired commands with a set of "next if *condition*" statements.

```ruby
# the json variable is defined higher up as a json builder object
commands.each do |command|
  next if command.type == "expand"
  next if command.type == "contract"
  json << command.to_json
end
```

### My Reaction: Ugh! Should use #select then #each

As I bounced around the codebase, I noticed this pattern in several places. Some had a single "next if" and others had quite a few. My initial reaction to this was "Ugh! Stinky! I prefer to use #select, followed by #each" The use of this pattern wasn't related to the bug I was helping resolve, so I just passed over it, although I'm sure I made a small grunting noise.
>Note: There is another smell here around the closure over the variable, json. I won't be talking about that.

### Why this reaction? What is wrong with this pattern?

The code worked.

So, why did I have this reaction to that pattern? What makes me strongly prefer a filter/process approach over a simple loop/(short-circuit/process) one? Over the past few years, I've become fascinated by the idea of understanding "why" one uses a certain technique. As I've been teaching more, I find myself sharing the idea "I don't care how you do it, as long as you have a justifiable, thought-out reason for it." It is common to challenge people to explain their decisions in terms of fundamentals, principles like [SOLID](http://butunclebob.com/ArticleS.UncleBob.PrinciplesOfOod) and the [4 Rules of Simple Design](http://c2.com/cgi/wiki?XpSimplicityRules).
So, why not hold myself to the same standard? What is my "justifiable, thought-out reason" for disliking this pattern and preferring a filter/process approach?

### What's the difference?

In order to compare them, it helps to characterize the two patterns. Is there a fundamental difference between them? After some thought, I came to a statement of difference as **"Iterating over a list and filtering"** and **"Iterating over a filtered list."** Once I had this differentiation, I could spend some time thinking of them independently.

## Iterating over a list, filtering

### A common pattern

The first form, iterating over a list, doing all the work in the loop body, is fairly common. In the case above, for example, the filtering/processing were inter-mingled in the same clause. As a reminder, this is what it looks like.

```ruby
commands.each do |command|
  next if command.type == "delete"
  next if command.type == "transfer"
  json << command.to_json
end
```

### Used to be the main technique

Back before most languages adopted iterator-style syntax, we all did our loops with a for statement: doing explicit iteration over a list, embedding our guard clauses into the block, itself.

```javascript
for(int i = 0; i < commands.count; i++) {
  if(command[i].type === 'update') {
    // Process this command
  }
}
{% endhighlight %}
or, perhaps your language supported an index-free form
{% highlight ruby %}
for command in commands
  if(command.type == 'update')
    # Process this command
  end
end
```

### Enumerable#each becomes "the thing to use"

As languages introduced (or, in certain cases, people discovered the language support) enumerator-style syntaxes, people began abandoning the explicit looping constructs. In Ruby, Enumerable#each became all the rage, leaving the lowly *for* keyword sad and abandoned, looking for things to loop over, calling out in the night, dreaming of the day when it, too, could yield up items without fear of over-flowing bounds.

Using this newer style feels strong. This abstraction of iteration almost feels safer. It feels "functional." There is a sense of extracting the loop semantics from the processing, which feels a bit more maintainable, too. The conversion is fairly easy, too, just take whatever was in the body of the for loop and move it to the body of the #each call.

###But often the switch stops there

Often the switch often stops here. The satisfaction of using Enumerable#each, especially without thought of the "why," leads to a sense of stability. So, we don't continue in converting our mindset to a more list-processing style.

### What value does Enumerable#each give over the *for* statement?
Stopping here begs the question of value, though. Is there a fundamental difference between a for-loop and calling #each with a block? Especially when the language already provides an index-free looping construct, such as Ruby's for.

After all, we're still effectively combining all the processing together. Although it feels "functional," we should ask ourselves what that means and whether this really exemplifies the "functional" philosophy.

## Iterating over a filtered list

### "And" is often an indication that a process is doing too much

Whenever I find a description of a style that contains the word "and," such as "iterating over a list and filtering," I take it as a sign that there could be a different, more decoupled way to do this. "And" often signals that a process is doing too many things. This can be bad, as it often mixes concerns, coupling together several responsibilities. The result often is difficulty changing the code when the time comes.

### Splitting the "And"

One technique I use when looking at a process that includes an "and" is to see if each clause's responsibility can be satisfied separately. In our case, we have "iterating and filtering," so let's look at doing these two processes separately. Moving them separately leads to "Iterating over a filtered list," where the filtering has already been done.

### Thinking in small chunks

Splitting the different tasks into separate parts allows us to think in terms of the individual responsibilities. For example, what is the result of filtering? What is the task that is being done on each element?

This could look like the following bit of code.

```ruby
commands.select do |command|
  ["create", "update"].include? command.type
end.each do |command|
  json << command.to_json
end
```

or, if it makes more sense to talk about what *isn't* included

```ruby
commands.reject do |command|
  ["delete", "transfer"].include? command.type
end.each do |command|
  json << command.to_json
end
```

## Splitting allows you to name the pieces
By decomposing purposefully into a filter/process step, you can improve the readability of the code.

### What is the actual list being processed?
In our example, when we separate out the filter step from the processing step, we also give ourselves a way to better reveal the goal, explicitly naming our list to process.

```ruby
def creation_based_commands
  self.commands.select { |command| ["create", "update"].include? command.type }
end

creation_based_commands.each { |command| json << command.to_json } 
```

This isn't always needed, but it is worth thinking about the person who is going to come to this codebase later to make a change. In general, the more explicit we are, the better.

After all, "Reveals Intent" is one of the [4 Rules of Simple Design](http://c2.com/cgi/wiki?XpSimplicityRules).

##Iterating over a list, filtering - have to think about what the filter is for
When you come to code that looks like this.

```ruby
# the json variable is defined higher up as a json builder object
commands.each do |command|
  next if command.type == "delete"
  next if command.type == "transfer"
  json << command.to_json
end
```

You have to spend some time thinking "why aren't these included?" "Are there others?" or "Should I add my new type to this list?"

## Iterating over a filtered list - provide opportunity to explicitly name the concept that the filtered list represents
This focus can also be used to effectively put a name on the filter. By separating the filtering into a first-class part of your processing, you can more clearly communicate the intent.

## Could just combine all the "next if" values into an array
Is splitting into a filter/process flow the only one? Surely we could just encapsulate the name of the types into an array and use that.

```ruby
# the json variable is defined higher up as a json builder object
commands.each do |command|
  next unless CREATION_TYPES.include?(command.type)
  json << command.to_json
end
```

### This works okay for simple cases, but still suffers from some of the issues outlined above
This can be tempting. And, as an initial step, it isn't too bad. This works reasonable well for simple cases like this, but starts to degrade a bit when we have more complex logic. That complex logic could be encapsulated in a method.

```ruby
# the json variable is defined higher up as a json builder object
commands.each do |command|
  next unless creation_command?(command)
  json << command.to_json
end
```

By doing this, we've extracted the logic for the filtering to another place. At this point, though, we are just a simple step away from a full decoupling. Should we take the last step?

##Inhibiting change
One argument for taking the last decoupling step is that it will make the code easier to change in the future. Paying attention to the Single Responsibility Principle (SRP) at this low level can often pay off when we come back to the code. We'll talk about that in a later section on analyzing the code based on SRP and the Open-Closed Principle to this code.

##Theory Talk
###Filtering/Transforming/Using

When decomposing a complex process into steps like this, I think in terms of Filter/Transform/Reduce/Use.

* Filter - Generate a subset of a list, based on a certain quality of each item.
* Transform - Generate a new list consisting of elements based on their respective original element.
* Reduce - Collapse a list into a single element.
* Use - Act in some fashion on each element of a list, generally resulting in a side-effect.

Decomposing a process into these is really a matter of building a composition-based pipeline for the data you are processing.

###Data pipelining

Data pipelining is a method for focusing on the workflow and transformations that a set of data undergoes when processing.

###Each technique has a focus and point

A major benefit of pipelining in this fashion is that each step has a strong focus and point. While the final composition might have complex behavior, the individual parts are easily understood as a step in the final process. Having small, focused parts help in maintaining code, moving us closer to the SOLID principles.

###SRP

####Each clause should have a single reason to change

For example, when decomposed properly, each step can be looked at as abiding by the Single Responsibility Principle. That is, each step has a single reason to change. If the filtering needs to change, it can be altered independently of the future processing. Any transformation or processing of the filtered set can be very explicit and focused on what needs to be done.

###OCP

####Enhancements can often be made by adding clauses, rather than changing existing ones

Just like effective object decomposition, breaking into small, focused clauses can help gain the benefits of the Open-Closed Principle. If you need to alter the workflow, you can often do this by adding clauses, rather than changing existing ones.

### Unix mentality

#### Pipelining through single, fit-for-purpose utilities

Data pipelining of this fashion isn't really a new or ground-breaking idea. Most of us spend time on the unix command-line, where a world of small, focused utilities is an environment we live in. Think of all the wonderfully complex actions that can be done by just stringing simple steps together. For example, here's a script to calculate the [churn in files in your git repository](https://github.com/garybernhardt/dotfiles/blob/master/bin/git-churn).

##Concerns

###Iterating multiple times over list
One of the major push backs on this style of list processing is the idea that you are then iterating multiple times over the same list. If you have N items, then you feasibly could be looping M#N times, where M is the number of steps in your process.

My first response is that this rarely is an issue that will affect you. In general, readability and maintainability trump this level of optimization.

Now, if your lists get to the size where this does cause problems, you can always look at lazy iterators. These chain the iterator, itself, rather than a primitive data structure, such as an Array. Some languages do this by default, and Ruby 2.0 has [added them to the standard library](http://ruby-doc.org/core-2.0.0/Enumerable.html#method-i-lazy).

###Difficulty in understanding / tracking process
Another common complaint is that separating these steps out can deter understanding/comprehension of what is going on and what the final result should be.

Of course, this is a common complaint against object decomposition, as well. As I like to say, "I've not really seen too many classes, but I've seen a lot of crappy abstractions." I think that sentiment comes into play in the situation here, as well. When decomposing a series of steps, it can be important to think about the flow of the data in understandable, readable steps.

## Benefit - Can be easier to debug
When separating a process into small, composable pieces, we often find the system is much easier to debug. Each step can be run individually to verify that it is doing its job correctly.

###Composition can be tested at different levels
If we have a problem with the fully-composed pipeline, we can more easily debug it by separating out different levels of composition to see that the data is processed correctly each step of the way.

###Examples for each piece can provide clarity
Each individual piece can be tested in isolation. Not just testing for verification, though, but also for clarity. The set of examples we write while isolation testing can give valuable feedback on the purpose of the unit.


Thanks to [Sarah Gray](https://twitter.com/fablednet) for proof-reading this post.
