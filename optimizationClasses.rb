class ReqScores
  attr_accessor :gzip_score, :gzip_total,:gzip_target, :keep_alive_score
  def initialize()
    @gzip_score = -1
    @gzip_total = 0
    @gzip_target = 0
    @keep_alive_score = -1
  end
end
