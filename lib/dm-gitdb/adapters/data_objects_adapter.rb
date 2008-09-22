require 'fileutils'
module DataMapper
  module Adapters
    module GitDbAdapter
      include FileUtils

      attr_writer :git
      def git
        return @git if @git
        git_initialize
        @git
      end
      
      def config_git(git_config)
        @git_config = git_config
        ::DataMapper.set_auto_increment(git_config[:increment_offset])
      end

      def git_config
        @git_config
      end

      def git_initialize
        mkdir_p(git_config[:local]) unless File.exists?(git_config[:local])
        begin
          self.git = Git.open(git_config[:local])
        rescue ArgumentError => e
          self.git = Git.init(git_config[:local])
        end
      end
      
      def git_file(record, absolute=false)
        return if git.nil?
        pdir = record.class.storage_name(self.name)
        mkdir_p(git_config[:local] / pdir) unless File.exists?(git_config[:local] / pdir)
        return git_config[:local] / pdir / record.id.to_s if absolute
        pdir / record.id.to_s
      end
      
      def git_update(record)
        return if record.new_record? || git.nil?
        File.open(git_file(record, true), "w") {|f| f.puts(to_json(record))}
        m = git.add(git_file(record))
        DataMapper.logger.debug("GitDb: in #{self.name}, git add => #{m}")
        
      end

      def git_remove(record)
        return if record.new_record? || git.nil?
        begin
          m = self.git.remove(git_file(record))
          DataMapper.logger.debug("GitDb: in #{self.name}, git remove => #{m}")
          
          rm_f(git_file(record, true))
        rescue Git::GitExecuteError => e
          raise e unless e.message.include?("did not match any files")
        end
      end

      def git_commit(message)
        return if self.git.nil?
        begin
          self.git.add('.')
          m = self.git.commit_all(message)
          DataMapper.logger.debug("GitDb: in #{self.name}, git commit => #{m}")
          
        rescue Git::GitExecuteError => e
          return if e.message.include?("nothing to commit")
          return if e.message.include?("did not match any files")
          raise e
        end
      end

      def git_pull(remote = 'origin', branch = 'master', message = 'origin pull')
        m = self.git.pull(remote, branch, message)
        DataMapper.logger.debug("GitDb: in #{self.name}, git pull #{remote} #{branch} => #{m}")
      end

      def git_clone(from)
        begin
          self.git = Git.open(git_config[:local])
          self.git.pull
        rescue ArgumentError => e
          self.git = Git.clone(from.git_config[:local], self.git_config[:local])
        end
      end

      def config_remotes(adapters)
        others = adapters.reject{|ad| ad == self}
        others.each do |adapter|
          next if self.git.remotes.detect{|r| r.name == adapter.name.to_s }
          self.git.add_remote(adapter.name.to_s, adapter.git_config[:as_url])
        end
      end


      def full_db_update
        changeset = {}
        self.git.ls_files.each do |path, attrs|
          table_name, id = path.split('/')
          changeset['new'] ||= {}
          changeset['new'][table_name] ||= []
          changeset['new'][table_name] << {:id => id, :values => JSON.parse(self.git.cat_file(attrs[:sha_index]))}
        end
        batch_update(changeset)
      end

      def diff_db_update(from, to)
        changeset = {}

        self.git.diff(from, to).each do |f|
          table_name, id = f.path.split('/')
          if f.type == 'new' || f.type == 'modified'
            fcon = f.blob(:dst)
            values = JSON.parse(fcon.contents) if fcon
          end
          changeset[f.type] ||= {}
          changeset[f.type][table_name] ||= []
          changeset[f.type][table_name] << {:id => id, :values => values}
        end

        batch_update(changeset)
      end

      def to_json(record)
        result = "{\n"

        propset = record.class.properties(self.name)

        fields = propset.map do |property|
          "#{property.field(self.name).to_json}: #{property.get(record).to_json}"
        end

        result << fields.join(", \n")
        result << "\n}\n"
        result
      end

      private
      
      def batch_update(changeset)
        
        changeset.each do |t, table_values|

          if t == 'new'
            table_values.each do |table_name, vals|
              git_db_create(table_name, vals.collect{|h| h[:values]})
            end
          elsif t == 'modified'
            table_values.each do |table_name, vals|
              vals.each do |h|
                git_db_update(table_name, h[:id], h[:values])
              end
            end
          elsif t == 'deleted'
            table_values.each{|table_name, vals| git_db_remove(table_name, vals.collect{|h| h[:id]})}
          end
        end
      end
      
      def git_db_create(table_name, fields)
        statement = "INSERT INTO #{quote_table_name(table_name)} "

        values = []
        
        if fields.is_a?(Array)
          columns = fields.first.keys
          values_statement = fields.collect{|row| "(#{(['?'] * row.size) * ', '})"}.join(', ')
          fields.each do |row| 
            columns.each {|column| values << row[column]}
          end
        else
          columns = fields.keys
          values_statement = "(#{(['?'] * fields.size) * ', '})"
          values = fields.values
        end

        statement << <<-EOS.compress_lines
          (#{columns.map { |field| quote_column_name(field) } * ', '})
          VALUES
          #{values_statement}
        EOS

        execute(statement, *values)
      end

      def git_db_remove(table_name, ids)
        return if ids.blank?
        statement = "DELETE FROM #{quote_table_name(table_name)}"
        statement << " WHERE id IN (#{(['?'] * ids.size) * ', '})"
        execute(statement, *ids)
      end

      def git_db_update(table_name, id, fields)
        update_fields = fields.reject{|k, v| k == 'id'}
        set_statement = update_fields.map { |field, value| "#{quote_column_name(field)} = ?" } * ', '

        statement = "UPDATE #{quote_table_name(table_name)}"
        statement << " SET #{set_statement}"
        statement << " WHERE id = ?"

        execute(statement, *(update_fields.values << id))
      end

    end
    
    
    class DataObjectsAdapter
      include GitDbAdapter
    end
  end # module Adapters
end # module DataMapper
