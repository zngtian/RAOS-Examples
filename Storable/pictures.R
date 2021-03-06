if (0){

error.plot <- function (summ, label){
  colors <- c("blue", "green", "red")
  round <- summ[,"round"]
  binary <- summ[,"Error.binary"]
  distance <- summ[,"Error.distance"]
  vote <- summ[,"vote"]
  par (mar=c(5,5,4,1)+.1)
  plot (jitt(round,.2), jitt(binary,.04), xlab="time", ylab="Error rate",
    pch=16, cex=.7, cex.lab=1.5, cex.axis=1.5, cex.main=1.5,ylim=c(-.03,1.03),
    main=paste("error counting,", label), col=colors[vote])
  temp <- binned.means (round, binary)
  par (mar=c(5,5,4,1)+.1)
  plot (jitt(round,.2), jitt(distance,1), xlab="time", ylab="Error distance",
    pch=16, cex=.7, cex.lab=1.5, cex.axis=1.5, cex.main=1.5,
    main=paste("error weighting,", label), col=colors[vote])
  temp <- binned.means (round, distance)
}

errcount2 <- function (value.i, vote.i, round.i, cut1.i, cut2.i){
  n <- length(value.i)
  n.cutpairs <- length(cut1.i)
  value <- array (value.i, c(n, n.cutpairs))
  vote <- array (vote.i, c(n,n.cutpairs))
  round <- array (round.i, c(n,n.cutpairs))
  cut1 <- t (array (cut1.i, c(n.cutpairs,n)))
  cut2 <- t (array (cut2.i, c(n.cutpairs,n)))
  expected <- ifelse (value<=cut1, 1, ifelse (value<=cut2, 2, 3))
  w <- round*(round+max(round))
  err.rate <- apply (vote!=expected, 2, mean)
  w.err.rate <- apply (w*(vote!=expected), 2, mean) / apply (w, 2, mean)
  error <- ifelse (vote==expected, 0,
    ifelse (vote==1, value-cut1,
    ifelse (vote==3, cut2-value,
    ifelse (expected==1, cut1-value, value-cut2))))
  err.mean <- apply (error, 2, mean)
  w.err.mean <- apply (w*error, 2, mean) / apply (w, 2, mean)
  cbind (err.rate, err.mean, w.err.rate, w.err.mean)
}

binned.means <- function (x, y, breaks=NULL, add=0, plot=T, ...){
  if (is.null(breaks)){
    nbins=floor(sqrt(length(x)))
    breaks <- quantile (x, seq(0,1,length=(nbins+1)))
    breaks[nbins+1] <- breaks[nbins+1] + 10^10
  }
  else {
    nbins <- length(breaks)-1
  }
  xmean <- NULL
  ymean <- NULL
  for (i in 1:nbins){
    cond <- x>=breaks[i] & x<breaks[i+1]
    xmean <- c(xmean, mean(x[cond]))
    ymean <- c(ymean, mean(y[cond]))
    if (plot) lines (breaks[i:(i+1)], add + rep(ymean[i],2), ...)
  }
  if (plot){
    for (i in 2:nbins){
      lines (rep(breaks[i],2), add + ymean[(i-1):i], ...)
    }
  }
  return (list (xmean=xmean, ymean=ymean))
}

empirical <- function (summ, label){
  value <- summ[,"value"]
  vote <- summ[,"vote"]
  plot (c(0,100), c(0,1), xlab="value", ylab="", type="n", xaxs="i", yaxs="i",
    cex.lab=1.3, cex.axis=1.3, cex.main=1.3, main=label)
  binned.means (value, ifelse(vote<3,1,0), breaks=seq(0,100,5), add=.002,
                col="darkgray")
  binned.means (value, ifelse(vote<2,1,0), breaks=seq(0,100,5), add=-.002,
                col="darkgray")
  text (10, .1, "1", cex=2)
  text (50, .5, "2", cex=2)
  text (90, .9, "3", cex=2)
  lines (c(0,100),c(0,0))
  lines (c(0,100),c(1,1))
}

monotonic <- function (data, rule="down", rounds=c(0,100)){
  players <- as.vector(unique (data[,"person"]))
  players <- players[(players!="NA") & (players!="")]
  n.players <- length(players)
  best.cuts <- array (NA, c(n.players,12))
  dimnames (best.cuts) <- list (players, c(
    "cut1.rate", "cut2.rate", "err.rate",
    "cut1.mean", "cut2.mean", "err.mean",
    "cut1.rate.w", "cut2.rate.w", "err.rate.w",
    "cut1.mean.w", "cut2.mean.w", "err.mean.w"))
  for (i in 1:n.players){
    pl <- players[i]
    ok <- data[,"person"]==pl & data[,"proposal"]==1 &
      data[,"round"]>=rounds[1] & data[,"round"]<=rounds[2]
    ok[is.na(ok)] <- F
    round <- as.vector(data[ok,"round"])
    value <- abs(as.numeric(as.vector(data[ok,"value"])))
    vote <- abs(as.numeric(as.vector(data[ok,"vote"])))
    cut.poss <- c(0,sort(as.vector(unique(value)))+.5)
    n.cut.poss <- length(cut.poss)
    cut1.all <- NULL
    cut2.all <- NULL
    errs.all <- NULL
    if (rule=="down"){
      for (i1 in 1:n.cut.poss){
        cut1 <- rep (cut.poss[i1], n.cut.poss+1-i1)
        cut2 <- cut.poss[i1:n.cut.poss]
        cut1.all <- c (cut1.all, cut1)
        cut2.all <- c (cut2.all, cut2)
        errs.all <- rbind(errs.all, errcount2 (value, vote, round, cut1, cut2))
      }
    }
    else if (rule=="up"){
      for (i2 in n.cut.poss:1){
        cut1 <- cut.poss[i2:1]
        cut2 <- rep (cut.poss[i2], i2)
        cut1.all <- c (cut1.all, cut1)
        cut2.all <- c (cut2.all, cut2)
        errs.all <- rbind(errs.all, errcount2 (value, vote, round, cut1, cut2))
      }
    }
    best.rate <- argmin (errs.all[,1])$argmin[1]
    best.mean <- argmin (errs.all[,2])$argmin[1]
    best.rate.w <- argmin (errs.all[,3])$argmin[1]
    best.mean.w <- argmin (errs.all[,4])$argmin[1]
    best.cuts[i,] <- c (
      cut1.all[best.rate], cut2.all[best.rate], errs.all[best.rate,1],
      cut1.all[best.mean], cut2.all[best.mean], errs.all[best.mean,2],
      cut1.all[best.rate.w], cut2.all[best.rate.w], errs.all[best.rate.w,3],
      cut1.all[best.mean.w], cut2.all[best.mean.w], errs.all[best.mean.w,4])
  }
  return (best.cuts)
}

}

simple.and.nash <- function (data, rounds=c(0,100), simple=c(33.3,66.7), nash=c(50,50)){
  players <- as.vector(unique (data[,"person"]))
  players <- players[(players!="NA") & (players!="")]
  n.players <- length(players)
  output <- array (NA, c(n.players,2))
  err.mean.simple <- rep(NA, n.players)
  err.mean.nash <- rep(NA, n.players)
  ll.simple <- rep(NA, n.players)
  ll.nash <- rep(NA, n.players)
  n <- rep(NA, n.players)
  for (i in 1:n.players){
    pl <- players[i]
    ok <- data[,"person"]==pl & data[,"proposal"]==1 &
      data[,"round"]>=rounds[1] & data[,"round"]<=rounds[2]
    ok[is.na(ok)] <- F
    round <- as.vector(data[ok,"round"])
    value <- abs(as.numeric(as.vector(data[ok,"value"])))
    vote <- abs(as.numeric(as.vector(data[ok,"vote"])))
    err.mean.simple[i] <- mean (!((value<simple[1] & vote==1) | (value>simple[1] & value<simple[2] & vote==2) |(value>simple[2] & vote==3)))
    err.mean.nash[i] <- mean(!((value<nash[1] & vote==1) | (value>nash[1] & value<nash[2] & vote==2) |(value>nash[2] & vote==3)))
    ll.simple[i] <- ll (sum(ok), err.mean.simple[i])
    ll.nash[i] <- ll (sum(ok), err.mean.nash[i])
    n[i] <- sum(ok)
  }
  ll.simple.total <- ll(sum(n),sum(err.mean.simple*n)/sum(n))
  ll.nash.total <- ll(sum(n),sum(err.mean.nash*n)/sum(n))
  print(n)
  print (c(round(ll.simple.total,0), round(ll.nash.total,0)))
  output <- cbind (err.mean.simple, err.mean.nash, ll.simple, ll.nash)
  return (output)
}

if (0){

monotonic.aggregate <- function (data, rule="down", rounds=c(0,100)){
  players <- as.vector(unique (data[,"person"]))
  players <- players[(players!="NA") & (players!="")]
  n.players <- length(players)
  best.cuts <- rep (NA, 12)
  names (best.cuts) <- c(
    "cut1.rate", "cut2.rate", "err.rate",
    "cut1.mean", "cut2.mean", "err.mean",
    "cut1.rate.w", "cut2.rate.w", "err.rate.w",
    "cut1.mean.w", "cut2.mean.w", "err.mean.w")
    ok <- data[,"proposal"]==1 &
      data[,"round"]>=rounds[1] & data[,"round"]<=rounds[2]
    ok[is.na(ok)] <- F
    round <- as.vector(data[ok,"round"])
    value <- abs(as.numeric(as.vector(data[ok,"value"])))
    vote <- abs(as.numeric(as.vector(data[ok,"vote"])))
    cut.poss <- c(0,sort(as.vector(unique(value)))+.5)
    n.cut.poss <- length(cut.poss)
    cut1.all <- NULL
    cut2.all <- NULL
    errs.all <- NULL
    if (rule=="down"){
      for (i1 in 1:n.cut.poss){
        cut1 <- rep (cut.poss[i1], n.cut.poss+1-i1)
        cut2 <- cut.poss[i1:n.cut.poss]
        cut1.all <- c (cut1.all, cut1)
        cut2.all <- c (cut2.all, cut2)
        errs.all <- rbind(errs.all, errcount2 (value, vote, round, cut1, cut2))
      }
    }
    else if (rule=="up"){
      for (i2 in n.cut.poss:1){
        cut1 <- cut.poss[i2:1]
        cut2 <- rep (cut.poss[i2], i2)
        cut1.all <- c (cut1.all, cut1)
        cut2.all <- c (cut2.all, cut2)
        errs.all <- rbind(errs.all, errcount2 (value, vote, round, cut1, cut2))
      }
    }
    best.rate <- argmin (errs.all[,1])$argmin[1]
    best.mean <- argmin (errs.all[,2])$argmin[1]
    best.rate.w <- argmin (errs.all[,3])$argmin[1]
    best.mean.w <- argmin (errs.all[,4])$argmin[1]
    best.cuts <- c (
      cut1.all[best.rate], cut2.all[best.rate], errs.all[best.rate,1],
      cut1.all[best.mean], cut2.all[best.mean], errs.all[best.mean,2],
      cut1.all[best.rate.w], cut2.all[best.rate.w], errs.all[best.rate.w,3],
      cut1.all[best.mean.w], cut2.all[best.mean.w], errs.all[best.mean.w,4])
  return (best.cuts)
}

argmin <- function(a){
  m <- min (a, na.rm=T)
  i <- (1:length(a))[a==m]
  list (min=m, argmin=i)
}

summarize <- function (data, cuts, rounds=c(0,100)){
  players <- as.vector(unique (data[,"person"]))
  players <- players[(players!="NA") & (players!="")]
  n.players <- length(players)
  summ <- NULL
  for (i in 1:n.players){
    ok <- data[,"person"]==players[i] & data[,"Proposal"]==1 &
      data[,"round"]>=rounds[1] & data[,"round"]<=rounds[2]
    ok[is.na(ok)] <- F
    round <- as.vector(data[ok,"round"])
    value <- abs(as.numeric(as.vector(data[ok,"value"])))
    vote <- abs(as.numeric(as.vector(data[ok,"vote"])))
    ord <- order(value)
    cbind (round,value,vote)[ord,]
    exb <- error.binary (value, vote, cuts[i,"cut1.rate"], cuts[i,"cut2.rate"])$expected
    exd <-error.distance (value, vote, cuts[i,"cut1.mean"], cuts[i,"cut2.mean"])$expected
    eb <- error.binary (value, vote, cuts[i,"cut1.rate"], cuts[i,"cut2.rate"])$error
    ed <-error.distance (value, vote, cuts[i,"cut1.mean"], cuts[i,"cut2.mean"])$error
    summ <- rbind (summ, cbind (rep(i,sum(ok)), round, value, vote, exb, exd, eb, ed))
  }
  dimnames (summ) <- list (NULL, c("person", "round", "value", "vote",
    "Expected.binary", "Expected.distance", "Error.binary", "Error.distance"))
  return (summ)
}

postscript ("aggregate.ps", height=3, horizontal=F)
par (mfrow=c(1,3), oma=c(0,0,3,0))
for (i in 1:3){
  data <- data.by.gamesize[[i]]
  J <- length(unique(data[,"person"]))
  label <- paste (gamesize[i], "-player games\n(data from ", J, " subjects)",
                  sep="")
  empirical (data, label)
}
mtext ("Empirical votes, averaging over all persons in each experiment",
       outer=T)
dev.off()

postscript ("errors.logit.ps", height=2.5, horizontal=F)
par (mfrow=c(1,4), oma=c(0,0,3,0))
for (i in 1:4){
  data <- data.by.gamesize[[i]]
  label <- paste (gamesize[i], "-player games", sep="")
  if (i==4) label <- "Model fit to random votes"
  c1 <- data[,"cutoff.12"]
  c2 <- data[,"cutoff.23"]
  value <- data[,"value"]
  predicted <- ifelse (value<c1, 1, ifelse (value<=c2, 2, 3))
  vote <- data[,"vote"]
  person <- data[,"person"]
  err.rates <- NULL
  for (p in unique(person)){
    err.rates <- c(err.rates, mean((predicted!=vote)[person==p],na.rm=T))
  }
  hist (err.rates, breaks=seq(0,1,.05), xlab="Error rate", ylab="",
        main=label)
}
mtext ("Histograms of individual persons' error rates\n(cutpoints estimated from logit model)", outer=T)
dev.off()

postscript ("errors.min.ps", height=2.5, horizontal=F)
par (mfrow=c(1,4), oma=c(0,0,3,0))
for (i in 1:4){
  label <- paste (gamesize[i], "-player games", sep="")
  if (i==4) label <- "Model fit to random votes"
  hist (cuts[[i]][,"err.rate"], breaks=seq(0,1,.05),
        xlab="Error rate", ylab="", main=label)
}
mtext ("Histograms of individual persons' error rates\n(cutpoints estimated to minimize each person's error rates)", outer=T)
dev.off()

postscript ("errors.min.univ.ps", height=4.5, width=6.5, horizontal=F)
par (mfcol=c(2,3), oma=c(0,0,3,0))
for (i in 1:3){
  label <- paste (gamesize[i], "-player games\n(Caltech students)", sep="")
  id <- as.numeric(substr(row.names(cuts[[i]]),1,1))
  caltech <- school[id]==1
  ucla <- school[id]==2
  hist (cuts[[i]][caltech,"err.rate"], breaks=seq(0,1,.05),
        xlab="Error rate", ylab="", main=label)
  label <- paste (gamesize[i], "-player games\n(UCLA students)", sep="")
  hist (cuts[[i]][ucla,"err.rate"], breaks=seq(0,1,.05),
        xlab="Error rate", ylab="", main=label)
}
mtext ("Histograms of individual persons' error rates, by university\n(cutpoints estimated to minimize each person's error rates)", outer=T)
dev.off()

postscript ("errors.min.halves.ps", height=4.5, width=6.5, horizontal=F)
par (mfcol=c(2,3), oma=c(0,0,3,0))
for (i in 1:3){
  label <- paste (gamesize[i], "-player games\n(first 10 trials)", sep="")
  hist (cuts.part1[[i]][,"err.rate"], breaks=seq(0,1,.05),
        xlab="Error rate", ylab="", main=label)
  label <- paste (gamesize[i], "-player games\n(trials 11 and later)", sep="")
  hist (cuts.part2[[i]][,"err.rate"], breaks=seq(0,1,.05),
        xlab="Error rate", ylab="", main=label)
}
mtext ("Histograms of individual persons' error rates, early and late trials\n(cutpoints estimated to minimize each person's error rates)", outer=T)
dev.off()

postscript ("errors.dist.ps", height=2.5, horizontal=F)
par (mfrow=c(1,4), oma=c(0,0,3,0))
for (i in 1:4){
  label <- paste (gamesize[i], "-player games", sep="")
  if (i==4) label <- "Model fit to random votes"
  hist (cuts[[i]][,"err.mean"], breaks=seq(0,30,2),
        xlab="Avg error dist", ylab="", main=label)
}
mtext ("Histograms of individual persons' average error distances\n(cutpoints estimated to minimize each person's average error distance)", outer=T)
dev.off()

postscript ("errors.dist.univ.ps", height=4.5, width=6.5, horizontal=F)
par (mfcol=c(2,3), oma=c(0,0,3,0))
for (i in 1:3){
  label <- paste (gamesize[i], "-player games\n(Caltech students)", sep="")
  id <- as.numeric(substr(row.names(cuts[[i]]),1,1))
  caltech <- school[id]==1
  ucla <- school[id]==2
  hist (cuts[[i]][caltech,"err.mean"], breaks=seq(0,30,2),
        xlab="Avg error distance", ylab="", main=label)
  label <- paste (gamesize[i], "-player games\n(UCLA students)", sep="")
  hist (cuts[[i]][ucla,"err.mean"], breaks=seq(0,30,2),
        xlab="Avg error distance", ylab="", main=label)
}
mtext ("Histograms of individual persons' average error discances, by university\n(cutpoints estimated to minimize each person's average error distance)", outer=T)
dev.off()

postscript ("errors.dist.halves.ps", height=4.5, width=6.5, horizontal=F)
par (mfcol=c(2,3), oma=c(0,0,3,0))
for (i in 1:3){
  label <- paste (gamesize[i], "-player games\n(first 10 trials)", sep="")
  hist (cuts.part1[[i]][,"err.mean"], breaks=seq(0,30,2),
        xlab="Avg error distance", ylab="", main=label)
  label <- paste (gamesize[i], "-player games\n(trials 11 and later)", sep="")
  hist (cuts.part2[[i]][,"err.mean"], breaks=seq(0,30,2),
        xlab="Avg error distance", ylab="", main=label)
}
mtext ("Histograms of individual persons' average error distances, early and late trials\n(cutpoints estimated to minimize each person's average error distance)", outer=T)
dev.off()

theory <- rbind (c(50,50), c(35,67), c(45,55))
# these are theoretical cutpoints for 2, 3, 6-player games
postscript ("cutpoints.logit.ps", height=3, horizontal=F)
par (mfrow=c(1,4), oma=c(0,0,3,0))
for (i in 1:4){
  data <- data.by.gamesize[[i]]
  label <- paste (gamesize[i], "-player game", sep="")
  if (i==4) label <- "Model fit to random votes"
  round <- data[,"round"]
  c1 <- data[round==1,"cutoff.12"]
  c2 <- data[round==1,"cutoff.23"]
  sch <- data[round==1,"school"]
  par (pty="s")
  plot (c(0,100), c(0,100), xlab="1-2 cutpoint",
        ylab="2-3 cutpoint", main=label, type="n", xaxt="n", yaxt="n")
  axis (1, seq(0,100,25))
  axis (2, seq(0,100,25))
  abline (0,1,lty=2,lwd=.5)
  if (i==4)
    points (c1, c2, pch=20, cex=.5)
  else {
    points (c1[sch==1], c2[sch==1], col="black", pch=20, cex=.5)
    points (c1[sch==2], c2[sch==2], col="darkgray", pch=20, cex=.5)
    text (40,8,"Caltech students",adj=0,col="black", cex=.8)
    text (40,1,"UCLA students",adj=0,col="darkgray", cex=.8)
    points (theory[i,1], theory[i,2], pch=21, cex=1.5)
  }
}
mtext ("Individuals' cutpoints, estimated from logit model\n(circles show theoretical equilibrium values)", outer=T)
dev.off()

postscript ("cutpoints.min.ps", height=3, horizontal=F)
par (mfrow=c(1,4), oma=c(0,0,3,0))
for (i in 1:4){
  label <- paste (gamesize[i], "-player games", sep="")
  if (i==4) label <- "Model fit to random votes"
  c1 <- cuts[[i]][,"cut1.rate"]
  c2 <- cuts[[i]][,"cut2.rate"]
  data <- data.by.gamesize[[i]]
  round <- data[,"round"]
  sch <- data[round==1,"school"]
  par (pty="s")
  plot (c(0,100), c(0,100), xlab="1-2 cutpoint",
        ylab="2-3 cutpoint", main=label, type="n", xaxt="n", yaxt="n")
  axis (1, seq(0,100,25))
  axis (2, seq(0,100,25))
  abline (0,1,lty=2,lwd=.5)
  if (i==4)
    points (c1, c2, pch=20, cex=.5)
  else {
    points (c1[sch==1], c2[sch==1], col="black", pch=20, cex=.5)
    points (c1[sch==2], c2[sch==2], col="darkgray", pch=20, cex=.5)
    text (40,8,"Caltech students",adj=0,col="black", cex=.8)
    text (40,1,"UCLA students",adj=0,col="darkgray", cex=.8)
    points (theory[i,1], theory[i,2], pch=21, cex=1.5)
  }
}
mtext ("Individuals' cutpoints, estimated to minimize error rates\n(circles show theoretical equilibrium values)", outer=T)
dev.off()

postscript ("cutpoints.min.halves.ps", height=5.3, horizontal=F)
par (mfrow=c(2,3), oma=c(0,0,3,0), pty="s")
for (j in 1:2){
  if (j==1) cat ("first 10 trials:\n")
  else if (j==2) cat ("trials 11 and later:\n")
for (i in 1:3){
  if (i==1) cat ("2-player games:\n")
  else if (i==2) cat ("3-player games:\n")
  else if (i==3) cat ("6-player games:\n")
  if (j==1){
    c1 <- cuts.part1[[i]][,"cut1.rate"]
    c2 <- cuts.part1[[i]][,"cut2.rate"]
    label <- paste (gamesize[i], "-player games\n(first 10 trials)", sep="")
  }
  else{
    c1 <- cuts.part2[[i]][,"cut1.rate"]
    c2 <- cuts.part2[[i]][,"cut2.rate"]
    label <- paste (gamesize[i], "-player games\n(trials 11 and later)", sep="")
  }
  data <- data.by.gamesize[[i]]
  round <- data[,"round"]
  sch <- data[round==1,"school"]
  plot (c(0,100), c(0,100), xlab="1-2 cutpoint",
        ylab="2-3 cutpoint", main=label, type="n", xaxt="n", yaxt="n")
  axis (1, seq(0,100,25))
  axis (2, seq(0,100,25))
  abline (0,1,lty=2,lwd=.5)
cat ("caltech cutpoint 1:", c1[sch==1],"\n")
cat ("ucla cutpoint 1:", c1[sch==2],"\n")
cat ("caltech cutpoint 2:", c2[sch==1],"\n")
cat ("ucla cutpoint 2:", c2[sch==2],"\n")
#print (c1[sch==2])
#print (c1[sch==2])
  points (c1[sch==1], c2[sch==1], col="black", pch=20, cex=.5)
  points (c1[sch==2], c2[sch==2], col="darkgray", pch=20, cex=.5)
  text (40,8,"Caltech students",adj=0,col="black", cex=.8)
  text (40,1,"UCLA students",adj=0,col="darkgray", cex=.8)
  points (theory[i,1], theory[i,2], pch=21, cex=1.5)
}
}
mtext ("Individuals' cutpoints, estimated to minimize error rates,\nearly and late trials", outer=T)
dev.off()

postscript ("sampledata.ps", height=8, horizontal=F)
par (mfrow=c(3,3), oma=c(0,0,3,0))
plotted <- c(101, 106, 409, 303, 405, 504, 705, 112)
story <- c("Perfectly monotonic",
           "Approximately monotonic",
           "One aberrant observation",
           "One fuzzy and one sharp cutpoint",
           "Only 1's and 3's",
           "Almost only 3's",
           "No 3's",
           "Nearly random")
           
for (i in 1:length(plotted)){
  ok <- data.all[,"person"]==plotted[i]
  data <- data.all[ok,]
  c12 <- c (data[1,"cutoff.12"], data[1,"cutoff.23"])
  s <- data[1,"sd.logit"]
  plot (data[,"value"], data[,"vote"], xlim=c(0,100), ylim=c(1,3),
        xlab="Value", ylab="Vote", main=story[i], yaxt="n")
  axis (2, 1:3)
  temp <- seq (0,100,.1)
  prob <- array (NA, c(length(temp),n.cut+1))
  expected <- rep (NA, length(temp))
  prob[,1] <- 1 - invlogit ((temp-c12[1])/s)
  expected <- 1*prob[,1]
  for (i.cut in 2:n.cut){
    prob[,i.cut] <- invlogit ((temp-c12[i.cut-1])/s) -
      invlogit ((temp-c12[i.cut])/s)
    expected <- expected + i.cut*prob[,i.cut]
  }
  prob[,n.cut+1] <- invlogit ((temp-c12[n.cut])/s)
  expected <- expected + (n.cut+1)*prob[,n.cut+1]
  lines (temp, expected, lwd=.5)
  for (i.cut in 1:n.cut) lines (rep(c12[i.cut],2), i.cut+c(0,1), lwd=.5)
}
mtext ("Data from some example individuals (vertical lines show estimated cutpoints,\nand curves show expected responses from fitted robust logit models)",
       outer=T)
dev.off()

}
