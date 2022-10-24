import ngram_score as ns
fitness = ns.ngram_score('quadgrams.txt')
print(fitness.score('HELLOWORLD'))